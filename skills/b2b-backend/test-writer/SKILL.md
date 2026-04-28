---
name: b2b-backend-test-writer
description: |
  테스트 코드 작성 시 자동으로 로드되는 전문 지식.
  다음 상황에서 사용할 것:
  - 사용자가 테스트 코드를 작성하거나 요청할 때
  - /test-write 커맨드가 실행될 때
  - "테스트 작성", "테스트 추가", "test 코드" 등의 키워드가 포함된 요청 시
  다음 상황에서는 사용하지 않을 것:
  - 테스트 실행만 요청할 때 (gradle test, mvn test 등)
  - 테스트 결과 해석만 요청할 때
  - 기존 테스트의 리뷰/검토만 요청할 때 (/test-review 커맨드 사용)
allowed-tools: Read
user-invocable: false
---

## 테스트 작성 전문 지식

### 테스트 도구 사용 가이드

| 상황 | 사용 도구 |
|---|---|
| 테스트 케이스 목록만 도출 (코드 미작성) | `/test` 커맨드 |
| 테스트 코드 작성 | `/test-write` 커맨드 |
| 케이스 도출 → 작성 → 실행 → 디버깅 → 리뷰 자동 반복 | `/test-all` 커맨드 |
| 기존 테스트 코드 리뷰 (정적 분석) | `/test-review` 커맨드 |
| 실패한 테스트 디버깅 | `/test-debug` 커맨드 |
| 프로덕션 변경의 테스트 영향 분석 | `/test-impact` 커맨드 |
| 작성된 테스트 품질 검증 (실행 포함) | `test-verifier` 에이전트 |

### 테스트 유형 선택 기준

| 대상 레이어 | 권장 테스트 유형 | 어노테이션 | 사유 |
|---|---|---|---|
| Service (비즈니스 로직) | Unit | `@ExtendWith(MockitoExtension.class)` / `@ExtendWith(MockKExtension::class)` | 속도 우선, 의존성 Mock |
| Controller (API) | Slice | `@WebMvcTest` | 직렬화, 상태코드, 바인딩 검증 |
| Repository (쿼리) | Slice | `@DataJpaTest` | JPA 쿼리 정확성 검증 |
| 복합 시나리오 | Integration | `@SpringBootTest` + `@Testcontainers` | 전체 흐름, 트랜잭션 검증 |

### Spring Boot 버전별 분기

**Spring Boot 2.x:**
```java
import javax.persistence.*;
// @MockBean은 spring-boot-test에 포함
```

**Spring Boot 3.x:**
```java
import jakarta.persistence.*;
// @MockBean deprecated → @MockitoBean 사용 (Boot 3.4+)
```

**Spring Boot 3.4+ @MockBean 전환:**
```java
// Boot 3.3 이하
import org.springframework.boot.test.mock.mockito.MockBean;
@MockBean private OrderService orderService;

// Boot 3.4+ (@MockBean deprecated)
import org.springframework.test.context.bean.override.mockito.MockitoBean;
@MockitoBean private OrderService orderService;
```

Kotlin + SpringMockK 사용 시:
```kotlin
// com.ninja-squad:springmockk:3.x → Boot 3.3 이하
// com.ninja-squad:springmockk:4.0.0+ → Boot 3.4+ 호환
@MockkBean private lateinit var orderService: OrderService
```

판단 방법: `build.gradle(.kts)` 또는 `pom.xml`에서 `spring-boot-starter-parent` 버전을 확인한다.

### Mock 프레임워크별 패턴

#### Kotlin + MockK
```kotlin
@ExtendWith(MockKExtension::class)
class OrderServiceTest {
    @MockK private lateinit var orderRepository: OrderRepository
    @MockK private lateinit var eventPublisher: ApplicationEventPublisher
    @InjectMockKs private lateinit var orderService: OrderService

    @Test
    fun `should create order when valid request`() {
        // given
        val request = CreateOrderRequest(itemId = 1L, quantity = 2)
        val savedOrder = Order(id = 1L, itemId = 1L, quantity = 2)
        every { orderRepository.save(any()) } returns savedOrder
        every { eventPublisher.publishEvent(any()) } just Runs

        // when
        val result = orderService.createOrder(request)

        // then
        assertThat(result.id).isEqualTo(1L)
        verify(exactly = 1) { orderRepository.save(any()) }
        verify(exactly = 1) { eventPublisher.publishEvent(any<OrderCreatedEvent>()) }
    }

    @Test
    fun `should throw when item not found`() {
        // given
        val request = CreateOrderRequest(itemId = 999L, quantity = 1)
        every { orderRepository.save(any()) } throws ItemNotFoundException(999L)

        // when & then
        assertThatThrownBy { orderService.createOrder(request) }
            .isInstanceOf(ItemNotFoundException::class.java)
    }
}
```

#### Java + Mockito
```java
@ExtendWith(MockitoExtension.class)
class OrderServiceTest {
    @Mock private OrderRepository orderRepository;
    @Mock private ApplicationEventPublisher eventPublisher;
    @InjectMocks private OrderService orderService;

    @Test
    void should_create_order_when_valid_request() {
        // given
        var request = new CreateOrderRequest(1L, 2);
        var savedOrder = new Order(1L, 1L, 2);
        given(orderRepository.save(any())).willReturn(savedOrder);
        willDoNothing().given(eventPublisher).publishEvent(any());

        // when
        var result = orderService.createOrder(request);

        // then
        assertThat(result.getId()).isEqualTo(1L);
        then(orderRepository).should(times(1)).save(any());
        then(eventPublisher).should(times(1)).publishEvent(any(OrderCreatedEvent.class));
    }

    @Test
    void should_throw_when_item_not_found() {
        // given
        var request = new CreateOrderRequest(999L, 1);
        given(orderRepository.save(any())).willThrow(new ItemNotFoundException(999L));

        // when & then
        assertThatThrownBy(() -> orderService.createOrder(request))
            .isInstanceOf(ItemNotFoundException.class);
    }
}
```

### Controller Slice 테스트 패턴

#### Kotlin
```kotlin
@WebMvcTest(OrderController::class)
class OrderControllerTest {
    @Autowired private lateinit var mockMvc: MockMvc
    @MockkBean private lateinit var orderService: OrderService
    @Autowired private lateinit var objectMapper: ObjectMapper

    @Test
    fun `should return 201 when order created`() {
        val request = CreateOrderRequest(itemId = 1L, quantity = 2)
        val response = OrderResponse(id = 1L, itemId = 1L, quantity = 2)
        every { orderService.createOrder(any()) } returns response

        mockMvc.perform(
            post("/api/orders")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request))
        )
            .andExpect(status().isCreated)
            .andExpect(jsonPath("$.id").value(1L))
    }

    @Test
    @WithMockUser(roles = ["ADMIN"])
    fun `should return 200 when admin deletes order`() {
        every { orderService.deleteOrder(1L) } just Runs
        mockMvc.perform(delete("/api/orders/1"))
            .andExpect(status().isOk)
    }
}
```

#### Java
```java
@WebMvcTest(OrderController.class)
class OrderControllerTest {
    @Autowired private MockMvc mockMvc;
    @MockBean private OrderService orderService;  // Boot 3.4+ 에서는 @MockitoBean
    @Autowired private ObjectMapper objectMapper;

    @Test
    void should_return_201_when_order_created() throws Exception {
        var request = new CreateOrderRequest(1L, 2);
        var response = new OrderResponse(1L, 1L, 2);
        given(orderService.createOrder(any())).willReturn(response);

        mockMvc.perform(
            post("/api/orders")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request))
        )
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.id").value(1L));
    }

    @Test
    @WithMockUser(roles = "ADMIN")
    void should_return_200_when_admin_deletes_order() throws Exception {
        willDoNothing().given(orderService).deleteOrder(1L);
        mockMvc.perform(delete("/api/orders/1"))
            .andExpect(status().isOk());
    }
}
```

### Repository Slice 테스트 패턴

주의: `@DataJpaTest`는 기본적으로 `@Transactional`을 포함하여 각 테스트 후 롤백된다. JPA 쓰기 지연으로 인해 `save()` 후 실제 SQL이 실행되지 않을 수 있으므로, `TestEntityManager`로 `flush()/clear()`를 명시적으로 호출한다.

Testcontainers 컨테이너는 프로젝트 DB에 맞게 선택한다: MySQL → `MySQLContainer`, MariaDB → `MariaDBContainer`.

Spring Boot 3.1+ 에서는 `@ServiceConnection`으로 `@DynamicPropertySource`를 대체할 수 있다:
```java
@Container @ServiceConnection
static MySQLContainer<?> mysql = new MySQLContainer<>("mysql:8.0");
// @DynamicPropertySource 불필요
```

#### Kotlin
```kotlin
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers
class OrderRepositoryTest {
    companion object {
        @Container
        @JvmStatic
        val mysql = MySQLContainer("mysql:8.0").apply {
            withDatabaseName("test")
        }

        @DynamicPropertySource
        @JvmStatic
        fun properties(registry: DynamicPropertyRegistry) {
            registry.add("spring.datasource.url", mysql::getJdbcUrl)
            registry.add("spring.datasource.username", mysql::getUsername)
            registry.add("spring.datasource.password", mysql::getPassword)
        }
    }

    @Autowired private lateinit var orderRepository: OrderRepository
    @Autowired private lateinit var entityManager: TestEntityManager

    @Test
    fun `should find orders by status with pagination`() {
        // given
        repeat(15) { orderRepository.save(Order(status = OrderStatus.PENDING)) }
        entityManager.flush()
        entityManager.clear()

        // when
        val page = orderRepository.findByStatus(
            OrderStatus.PENDING, PageRequest.of(0, 10, Sort.by("id").descending())
        )

        // then
        assertThat(page.content).hasSize(10)
        assertThat(page.totalElements).isEqualTo(15)
    }
}
```

#### Java
```java
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers
class OrderRepositoryTest {
    @Container
    static MySQLContainer<?> mysql = new MySQLContainer<>("mysql:8.0")
        .withDatabaseName("test");

    @DynamicPropertySource
    static void properties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", mysql::getJdbcUrl);
        registry.add("spring.datasource.username", mysql::getUsername);
        registry.add("spring.datasource.password", mysql::getPassword);
    }

    @Autowired private OrderRepository orderRepository;
    @Autowired private TestEntityManager entityManager;

    @Test
    void should_find_orders_by_status_with_pagination() {
        // given
        for (int i = 0; i < 15; i++) {
            orderRepository.save(new Order(OrderStatus.PENDING));
        }
        entityManager.flush();
        entityManager.clear();

        // when
        var page = orderRepository.findByStatus(
            OrderStatus.PENDING, PageRequest.of(0, 10, Sort.by("id").descending())
        );

        // then
        assertThat(page.getContent()).hasSize(10);
        assertThat(page.getTotalElements()).isEqualTo(15);
    }
}
```

### Integration 테스트 패턴

주의: `@SpringBootTest` + `TestRestTemplate`은 실제 HTTP 요청을 별도 스레드에서 수행하므로, `@Transactional`을 붙여도 롤백이 적용되지 않는다. 반드시 `@AfterEach`에서 데이터를 정리해야 한다.

#### Kotlin
```kotlin
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
class OrderIntegrationTest {
    companion object {
        @Container
        @JvmStatic
        val mysql = MySQLContainer("mysql:8.0").apply {
            withDatabaseName("test")
        }

        @DynamicPropertySource
        @JvmStatic
        fun properties(registry: DynamicPropertyRegistry) {
            registry.add("spring.datasource.url", mysql::getJdbcUrl)
            registry.add("spring.datasource.username", mysql::getUsername)
            registry.add("spring.datasource.password", mysql::getPassword)
        }
    }

    @Autowired private lateinit var testRestTemplate: TestRestTemplate
    @Autowired private lateinit var orderRepository: OrderRepository

    @AfterEach
    fun cleanup() {
        orderRepository.deleteAllInBatch()
    }

    @Test
    fun `should create and retrieve order`() {
        // given
        val request = CreateOrderRequest(itemId = 1L, quantity = 2)

        // when
        val createResponse = testRestTemplate.postForEntity(
            "/api/orders", request, OrderResponse::class.java
        )

        // then
        assertThat(createResponse.statusCode).isEqualTo(HttpStatus.CREATED)
        val orderId = createResponse.body!!.id

        val getResponse = testRestTemplate.getForEntity(
            "/api/orders/$orderId", OrderResponse::class.java
        )
        assertThat(getResponse.body!!.quantity).isEqualTo(2)
    }
}
```

#### Java
```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
class OrderIntegrationTest {
    @Container
    static MySQLContainer<?> mysql = new MySQLContainer<>("mysql:8.0")
        .withDatabaseName("test");

    @DynamicPropertySource
    static void properties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", mysql::getJdbcUrl);
        registry.add("spring.datasource.username", mysql::getUsername);
        registry.add("spring.datasource.password", mysql::getPassword);
    }

    @Autowired private TestRestTemplate testRestTemplate;
    @Autowired private OrderRepository orderRepository;

    @AfterEach
    void cleanup() {
        orderRepository.deleteAllInBatch();
    }

    @Test
    void should_create_and_retrieve_order() {
        // given
        var request = new CreateOrderRequest(1L, 2);

        // when
        var createResponse = testRestTemplate.postForEntity(
            "/api/orders", request, OrderResponse.class
        );

        // then
        assertThat(createResponse.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        var orderId = createResponse.getBody().getId();

        var getResponse = testRestTemplate.getForEntity(
            "/api/orders/" + orderId, OrderResponse.class
        );
        assertThat(getResponse.getBody().getQuantity()).isEqualTo(2);
    }
}
```

### ParameterizedTest 패턴

입력값만 다른 동일 로직 테스트가 3개 이상이면 `@ParameterizedTest`로 통합한다.

#### Kotlin
```kotlin
@ParameterizedTest
@CsvSource(
    "0, INVALID_QUANTITY",
    "-1, INVALID_QUANTITY",
    "10001, EXCEEDS_LIMIT"
)
fun `should reject invalid quantity`(quantity: Int, expectedError: String) {
    val request = CreateOrderRequest(itemId = 1L, quantity = quantity)
    assertThatThrownBy { orderService.createOrder(request) }
        .isInstanceOf(BusinessException::class.java)
        .extracting("errorCode").isEqualTo(expectedError)
}
```

#### Java
```java
@ParameterizedTest
@CsvSource({
    "0, INVALID_QUANTITY",
    "-1, INVALID_QUANTITY",
    "10001, EXCEEDS_LIMIT"
})
void should_reject_invalid_quantity(int quantity, String expectedError) {
    var request = new CreateOrderRequest(1L, quantity);
    assertThatThrownBy(() -> orderService.createOrder(request))
        .isInstanceOf(BusinessException.class)
        .extracting("errorCode").isEqualTo(expectedError);
}
```

### Fixture 패턴

테스트 데이터 구성 코드가 테스트 로직보다 길어지면 Fixture를 분리한다.

#### Kotlin (copy 활용)
```kotlin
object OrderFixture {
    val DEFAULT = Order(itemId = 1L, quantity = 1, status = OrderStatus.PENDING)

    fun pending(itemId: Long = 1L, quantity: Int = 1) =
        DEFAULT.copy(itemId = itemId, quantity = quantity)

    fun confirmed(itemId: Long = 1L) =
        DEFAULT.copy(itemId = itemId, status = OrderStatus.CONFIRMED)
}

// 사용 예
val order = OrderFixture.pending(quantity = 5)
```

#### Java (Builder 활용)
```java
class OrderFixture {
    public static Order.OrderBuilder defaultOrder() {
        return Order.builder()
            .itemId(1L)
            .quantity(1)
            .status(OrderStatus.PENDING);
    }

    public static Order pending() { return defaultOrder().build(); }
    public static Order confirmed() {
        return defaultOrder().status(OrderStatus.CONFIRMED).build();
    }
}

// 사용 예
var order = OrderFixture.defaultOrder().quantity(5).build();
```

### 테스트 작성 시 반드시 확인할 체크리스트

1. **테스트 격리**: 각 테스트가 독립적으로 실행 가능한가?
2. **네이밍**: 테스트명만 보고 무엇을 검증하는지 알 수 있는가?
3. **단일 검증**: 한 테스트에 하나의 실패 사유만 있는가?
4. **경계값**: 빈 컬렉션, null, 0, 최대값 케이스를 포함했는가?
5. **예외 경로**: 비즈니스 예외와 시스템 예외를 분리하여 검증하는가?
6. **Mock 최소화**: 테스트 대상의 직접 의존성만 Mock했는가?
7. **Assertion 명확성**: AssertJ의 구체적 메서드(`isEqualTo`, `hasSize`, `containsExactly`)를 사용하는가?
8. **깨지기 쉬운 검증 방지**: 구현 상세가 아닌 행동을 검증하는가?

### 테스트 작성 시 하지 말아야 하는 것

1. **`Thread.sleep()`으로 비동기 대기하지 않는다** → `Awaitility` 또는 `CountDownLatch`를 사용한다.
2. **try-catch로 예외를 검증하지 않는다** → `assertThatThrownBy` 또는 `shouldThrow`를 사용한다.
3. **`@SpringBootTest`를 Unit 테스트에 사용하지 않는다** → `@ExtendWith`로 충분한지 먼저 판단한다.
4. **`@Transactional`을 통합 테스트에서 무분별하게 사용하지 않는다** → 자동 롤백이 실제 동작을 왜곡할 수 있다.
5. **`verify()`로 모든 Mock 호출을 빠짐없이 검증하지 않는다** → 핵심 부수효과만 검증한다.
6. **테스트 데이터에 매직 넘버를 사용하지 않는다** → 의미 있는 변수명으로 의도를 드러낸다.

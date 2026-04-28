---
name: b2b-backend-code-reviewer
description: |
  코드 리뷰 시 자동으로 로드되는 전문 지식.
  다음 상황에서 사용할 것:
  - 사용자가 코드 리뷰를 요청할 때 ("리뷰해줘", "코드 봐줘", "이 코드 어때", "PR 리뷰", "코드 리뷰", "변경 확인")
  다음 상황에서는 사용하지 않을 것:
  - 테스트 코드 작성/리뷰만 요청할 때 (test-writer skill 사용)
  - 단순 코드 설명을 요청할 때 ("이 코드가 뭐하는 거야")
  - 코드를 새로 작성하는 경우
allowed-tools: Read, Grep, Glob
user-invocable: false
---

## 코드 리뷰 전문 지식

### 리뷰 원칙

1. **변경 diff에 집중**: 변경하지 않은 코드를 지적하지 않는다.
2. **심각도 기반**: CRITICAL(운영 장애) > WARNING(잠재적 문제) > INFO(개선 제안) 순서로 중요도를 구분한다.
3. **수정 코드 필수**: CRITICAL과 WARNING에는 반드시 구체적 수정 코드를 포함한다.
4. **컨텍스트 이해**: 변경의 의도를 먼저 파악하고, 그 의도가 올바르게 구현되었는지 판단한다.
5. **코드 비수정**: 프로덕션 코드를 직접 수정하지 않는다. 수정 코드를 출력으로만 제시한다.
6. **원본 언어 유지**: 수정 코드는 원본 코드와 동일한 언어(Java/Kotlin)로 작성한다.

### 리뷰 도구 사용 가이드

| 상황 | 사용 도구 |
|---|---|
| 종합 리뷰 (일반적 경우) | `/review` 커맨드 |
| 보안 집중 리뷰 | `/review-security` 커맨드 |
| 성능 집중 리뷰 | `/review-perf` 커맨드 |
| 복잡도 제거 | `/simplify` 커맨드 |
| 리뷰 지적사항 수정 후 재확인 | `/review-fix` 커맨드 |
| PR 머지 전 배포/운영 관점 점검 | `/review-checklist` 커맨드 |
| 대규모 변경의 영향 범위/호환성 분석 | `deep-code-reviewer` 에이전트 |

### Spring Boot 계층별 체크리스트

#### Controller 계층

**Kotlin 안티패턴:**
```kotlin
// BAD: 입력 검증 누락
@PostMapping("/orders")
fun createOrder(@RequestBody request: CreateOrderRequest): ResponseEntity<OrderResponse> {
    return ResponseEntity.ok(orderService.createOrder(request))
}

// GOOD: @Valid + 201 상태 코드
@PostMapping("/orders")
fun createOrder(@Valid @RequestBody request: CreateOrderRequest): ResponseEntity<OrderResponse> {
    return ResponseEntity.status(HttpStatus.CREATED).body(orderService.createOrder(request))
}
```

**Java 안티패턴:**
```java
// BAD: 응답 포맷 불일관 (성공은 body, 에러는 Map)
@GetMapping("/orders/{id}")
public ResponseEntity<?> getOrder(@PathVariable Long id) {
    try {
        return ResponseEntity.ok(orderService.getOrder(id));
    } catch (NotFoundException e) {
        return ResponseEntity.status(404).body(Map.of("error", e.getMessage()));
    }
}

// GOOD: 전역 ExceptionHandler에 위임
@GetMapping("/orders/{id}")
public ResponseEntity<OrderResponse> getOrder(@PathVariable Long id) {
    return ResponseEntity.ok(orderService.getOrder(id));
}
// NotFoundException은 @RestControllerAdvice에서 처리
```

#### Service 계층

**트랜잭션 안티패턴:**
```kotlin
// BAD: 트랜잭션 내 외부 호출
@Transactional
fun createOrder(request: CreateOrderRequest): OrderResponse {
    val order = orderRepository.save(Order.from(request))
    paymentClient.charge(order.totalAmount)  // HTTP 호출 — 실패 시 DB 롤백되지만 결제는 이미 완료
    return OrderResponse.from(order)
}

// GOOD: 이벤트 기반 분리 + 리스너에서 커밋 후 처리
@Transactional
fun createOrder(request: CreateOrderRequest): OrderResponse {
    val order = orderRepository.save(Order.from(request))
    eventPublisher.publishEvent(OrderCreatedEvent(order.id))
    return OrderResponse.from(order)
}

// 이벤트 리스너 (반드시 AFTER_COMMIT으로 처리해야 트랜잭션 외부에서 실행됨)
@TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
fun handleOrderCreated(event: OrderCreatedEvent) {
    paymentClient.charge(event.orderId)
}
```

```java
// BAD: @Transactional이 private 메서드에 적용 (프록시 무시)
@Service
public class OrderService {
    @Transactional  // 효과 없음!
    private void internalProcess(Order order) { ... }
}

// GOOD: 별도 빈으로 분리하여 프록시가 동작하도록
@Service
@RequiredArgsConstructor
public class OrderService {
    private final OrderInternalProcessor internalProcessor;

    public void process(Order order) {
        internalProcessor.internalProcess(order);
    }
}

@Service
public class OrderInternalProcessor {
    @Transactional
    public void internalProcess(Order order) { ... }
}
// 참고: Spring Framework 6.0+에서는 private 메서드에 @Transactional 선언 시 로그 경고 발생
```

**동시성 안티패턴:**
```kotlin
// BAD: Read-Modify-Write 패턴에 동시성 제어 없음
@Transactional
fun decreaseStock(itemId: Long, quantity: Int) {
    val item = itemRepository.findById(itemId).orElseThrow()
    item.stock -= quantity  // 동시 요청 시 Lost Update
    itemRepository.save(item)
}

// GOOD: Optimistic Lock + 재시도 (충돌이 드문 경우)
// Entity에 @Version 필드 추가
@Retryable(
    retryFor = [OptimisticLockingFailureException::class],
    maxAttempts = 3,
    backoff = Backoff(delay = 50)
)
@Transactional
fun decreaseStock(itemId: Long, quantity: Int) {
    val item = itemRepository.findByIdOrThrow(itemId)
    item.decreaseStock(quantity)  // 비즈니스 메서드에서 검증 포함
}

// 충돌이 잦은 경우(재고, 포인트 차감 등): Pessimistic Lock 검토
// @Lock(LockModeType.PESSIMISTIC_WRITE) + lock timeout 설정 필요
// 여러 테이블을 잠글 때는 항상 동일 순서로 잠금 획득 (데드락 방지)
```

**예외 처리 안티패턴:**
```kotlin
// BAD: 예외 삼킴
fun processOrder(orderId: Long) {
    try {
        orderService.process(orderId)
    } catch (e: Exception) {
        log.error("처리 실패")  // 원인 정보 소실
    }
}

// GOOD: 예외 체인 유지 + 구체적 예외 처리
fun processOrder(orderId: Long) {
    try {
        orderService.process(orderId)
    } catch (e: BusinessException) {
        log.warn("비즈니스 예외: orderId={}, code={}", orderId, e.errorCode)
        throw e
    } catch (e: Exception) {
        log.error("시스템 예외: orderId={}", orderId, e)  // 스택트레이스 포함
        throw SystemException("주문 처리 중 오류", e)
    }
}
```

#### Repository 계층

**N+1 쿼리:**
```kotlin
// BAD: Lazy 로딩 + 루프 접근
val orders = orderRepository.findByStatus(OrderStatus.PENDING)
orders.forEach { order ->
    println(order.items.size)  // 주문마다 SELECT 발생
}

// GOOD: Fetch Join
@Query("SELECT o FROM Order o JOIN FETCH o.items WHERE o.status = :status")
fun findByStatusWithItems(@Param("status") status: OrderStatus): List<Order>

// GOOD: @EntityGraph
@EntityGraph(attributePaths = ["items"])
fun findByStatus(status: OrderStatus): List<Order>

// GOOD: @BatchSize (연관관계 필드에 선언)
@BatchSize(size = 100)
@OneToMany(mappedBy = "order", fetch = FetchType.LAZY)
val items: MutableList<OrderItem> = mutableListOf()
```

**전체 조회:**
```java
// BAD: 전체 데이터 조회
List<User> users = userRepository.findAll();

// GOOD: 페이지네이션 적용
Page<User> users = userRepository.findAll(PageRequest.of(0, 20, Sort.by("id").descending()));
```

#### Domain 계층

**Entity 안티패턴 (Kotlin JPA Entity는 `kotlin-jpa` 플러그인 설정이 전제됨):**
```kotlin
// BAD: 무분별한 setter 노출
@Entity
class Order(
    var status: OrderStatus = OrderStatus.PENDING,
    var totalAmount: BigDecimal = BigDecimal.ZERO
)
// order.status = OrderStatus.CANCELLED  // 검증 없이 변경 가능

// GOOD: 비즈니스 메서드로 상태 변경
@Entity
class Order(
    status: OrderStatus = OrderStatus.PENDING,
    val totalAmount: BigDecimal = BigDecimal.ZERO
) {
    var status: OrderStatus = status
        private set

    fun cancel() {
        require(status == OrderStatus.PENDING) { "진행 중인 주문만 취소 가능" }
        status = OrderStatus.CANCELLED
    }
}
```

**Entity-Schema 정합성 안티패턴 (JPA 어노테이션이 동일하므로 Kotlin 예시만 제공):**
```kotlin
// BAD: DB에 UNIQUE 제약이 있지만 Entity에 미반영
// → ddl-auto 기반 테스트(H2 등)에서 UNIQUE 제약이 스키마에 생성되지 않아
//   중복 INSERT 예외 테스트가 실패하지 않음
@Entity
@Table(name = "device_token")
class DeviceToken(
    // ... (Id, 연관관계 등 생략)
    @Column(nullable = false, length = 512)
    val token: String,  // DB: VARCHAR(512) NOT NULL UNIQUE → unique = true 누락!
)

// GOOD: 마이그레이션 스크립트의 모든 제약을 Entity에 반영
@Entity
@Table(name = "device_token")
class DeviceToken(
    // ... (Id, 연관관계 등 생략)
    @Column(nullable = false, unique = true, length = 512)
    val token: String,
)
// 대조 대상: NOT NULL, UNIQUE, INDEX, VARCHAR 길이, DECIMAL(precision/scale),
// @Enumerated(STRING), FK optional/nullable
```

### 보안 핵심 체크리스트 (Quick Check)
> 상세 보안 리뷰는 `/review-security`를 사용한다. 아래는 종합 리뷰(`/review`) 시 빠르게 확인하는 항목이다.

| 항목 | 탐지 방법 |
|---|---|
| SQL Injection | Native Query에 문자열 결합(`+`, `${}`)이 있는가? |
| 인증 누락 | 새 Controller 메서드에 Security 설정이 있는가? |
| IDOR | PathVariable ID로 리소스를 직접 조회하면서 소유자 검증이 없는가? |
| 민감정보 | 비밀번호, API 키가 코드에 하드코딩되어 있는가? |
| 민감정보 응답 | 응답 DTO에 password, secret, token 필드가 포함되는가? |

### 성능 핵심 체크리스트 (Quick Check)
> 상세 성능 리뷰는 `/review-perf`를 사용한다. 아래는 종합 리뷰(`/review`) 시 빠르게 확인하는 항목이다.

| 항목 | 탐지 방법 |
|---|---|
| N+1 쿼리 | Lazy 연관관계를 루프 내에서 접근하는가? |
| 전체 조회 | `findAll()` 또는 조건 없는 전체 조회가 있는가? |
| 루프 내 DB 호출 | for/forEach 내부에서 Repository 메서드를 호출하는가? |
| 루프 내 외부 호출 | for/forEach 내부에서 HTTP/메시징 호출이 있는가? |
| 트랜잭션 내 외부 호출 | `@Transactional` 메서드 내에서 HTTP 호출이 있는가? |

### 리뷰 심각도 판단 기준

| 심각도 | 기준 | 예시 |
|---|---|---|
| CRITICAL | 운영 장애, 데이터 손실, 보안 취약점이 발생할 수 있는 문제 | SQL Injection, 트랜잭션 내 외부 호출, 인증 우회 |
| WARNING | 트래픽 증가 시 성능 저하, 유지보수 비용 증가, 잠재적 버그 | N+1, 예외 삼킴, @Transactional private 메서드 |
| INFO | 컨벤션 위반, 가독성 개선, 네이밍 제안 | 메서드명, 로그 레벨, 불필요한 import |

---
name: b2b-android-create-api
description: API 레이어 코드 자동 생성 (Service, Repository, Entity, VO, Mapper). "API 만들어줘", "서비스 생성", "레포지토리 추가", "엔티티 생성", "API 코드 작성" 요청 시 사용
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, AskUserQuestion
user-invocable: true
---

# API 레이어 자동 생성 스킬

API 통신에 필요한 모든 레이어 코드를 프로젝트 컨벤션에 맞게 자동 생성합니다.

## 실행 단계

### 1단계: API 정보 수집

사용자에게 다음 정보를 질문으로 수집:

1. **도메인 이름** (예: Shop, Cosmetic, Customer)
2. **API 엔드포인트** (예: GET /v1/shop/operation-settings)
3. **HTTP 메서드** (GET, POST, PUT, DELETE, PATCH)
4. **요청 파라미터**
   - Header: token 등
   - Path: shopNo 등
   - Query: page, size 등
   - Body: 있는 경우 필드 구조
5. **응답 구조** (JSON 예시 또는 필드 설명)
6. **UseCase 생성 여부** (복잡한 비즈니스 로직이나 페이징이 필요한 경우)

### 2단계: 파일 구조 확인

기존 코드 패턴 참조를 위해 읽기:
- `.docs/conventions/api-convention.md` - 전체 컨벤션
- 유사한 도메인의 기존 Service, Repository, Entity, VO 파일

### 3단계: Entity 생성

**위치**: `network/src/main/java/com/gongbiz/network/api/{domain}/entity/`

**파일명**: `{Action}{Domain}Entity.kt`

**규칙**:
- 모든 필드는 **nullable** (`?`) 선언
- 중첩된 객체도 nullable
- 기본값 없음
- KDoc 주석 추가

**예시**:
```kotlin
/**
 * 샵 영업 설정 조회 응답 Entity
 */
data class GetShopOperationSettingEntity(
    val result: String?,
    val operationTime: OperationTimeEntity?,
    val breakTime: List<BreakTimeEntity>?
) {
    data class OperationTimeEntity(
        val startTime: String?,
        val endTime: String?,
        val isActive: Boolean?
    )

    data class BreakTimeEntity(
        val id: Int?,
        val startTime: String?,
        val endTime: String?
    )
}
```

### 4단계: Body 생성 (POST/PUT/PATCH인 경우)

**위치**: `network/src/main/java/com/gongbiz/network/api/{domain}/body/`

**파일명**: `{Action}{Domain}Body.kt`

**규칙**:
- 필수 필드는 non-nullable
- 선택 필드는 nullable 또는 기본값 사용
- KDoc 주석 추가

### 5단계: Service Interface 생성/수정

**위치**: `network/src/main/java/com/gongbiz/network/api/{domain}/{Domain}Service.kt`

**규칙**:
- 기존 파일이 있으면 메서드만 추가
- `suspend fun` 사용
- **반환 타입 선택 (두 가지 패턴)**:
  - **v2 API (신규, Flow 사용)**: `ResponseBase<T>` 직접 반환
  - **v1 API (기존)**: `NetworkResponse<T, ErrorResponse>` 반환
- KDoc 주석 추가 (파라미터 설명 포함)
- Retrofit 어노테이션 사용 (@GET, @POST 등)

**예시 (v2 API - Flow 패턴)**:
```kotlin
/**
 * 샵 영업 요일/시간 조회 (v2)
 * @param token JWT 인증 토큰
 */
@GET("api/v2/business-day/shop")
suspend fun getShopBusinessDay(
    @Header(GD_AUTH_TOKEN) token: String
): ResponseBase<GetShopBusinessDayEntity>
```

**예시 (v1 API - NetworkResponse 패턴)**:
```kotlin
/**
 * 샵 영업 설정 조회 (v1)
 * @param token JWT 인증 토큰
 */
@GET("v1/shop/busi")
suspend fun getShopSetting(
    @Header(GD_AUTH_TOKEN) token: String,
    @Query(YOIL_SEQ) yoilseq: Int
): NetworkResponse<GetShopSettingEntity, ErrorResponse>
```

### 6단계: Repository Interface 생성/수정

**위치**: `network/src/main/java/com/gongbiz/network/api/{domain}/{Domain}Repository.kt`

**규칙**:
- 기존 파일이 있으면 메서드만 추가
- **반환 타입 선택 (Service 패턴에 맞춤)**:
  - **v2 API (ResponseBase 반환)**: `Flow<ResponseBase<T>>` 사용 (suspend 없음)
  - **v1 API (NetworkResponse 반환)**: `suspend fun` + `NetworkResponse<T, E>` 반환
- 페이징 필요 시: `suspend fun` + `ResponsePaging<T>` 반환

**예시 (v2 API - Flow 패턴)**:
```kotlin
interface ShopRepository {
    fun getShopBusinessDay(
        token: String
    ): Flow<ResponseBase<GetShopBusinessDayEntity>>
}
```

**예시 (v1 API - NetworkResponse 패턴)**:
```kotlin
interface ShopRepository {
    suspend fun getShopSetting(
        token: String,
        yoilseq: Int
    ): NetworkResponse<GetShopSettingEntity, ErrorResponse>
}
```

### 7단계: Repository Implementation 생성/수정

**파일명**: 같은 파일에 Implementation 추가 또는 별도 `{Domain}RepositoryImpl.kt`

**규칙**:
- `@Inject constructor` 사용
- **패턴별 구현**:
  - **v2 API (Flow)**: `flow { emit(service.method()) }` 패턴
  - **v1 API (suspend)**: `return service.method()` 직접 반환
- 페이징: `suspend fun`으로 직접 service 호출

**예시 (v2 API - Flow 패턴)**:
```kotlin
class ShopRepositoryImpl @Inject constructor(
    private val service: ShopService
) : ShopRepository {

    override fun getShopBusinessDay(
        token: String
    ): Flow<ResponseBase<GetShopBusinessDayEntity>> = flow {
        emit(service.getShopBusinessDay(token))
    }
}
```

**예시 (v1 API - NetworkResponse 패턴)**:
```kotlin
class ShopRepositoryImpl @Inject constructor(
    private val service: ShopService
) : ShopRepository {

    override suspend fun getShopSetting(
        token: String,
        yoilseq: Int
    ): NetworkResponse<GetShopSettingEntity, ErrorResponse> {
        return service.getShopSetting(token, yoilseq)
    }
}
```

### 8단계: VO (Value Object) 생성

**위치**: `app/src/main/java/com/gongnailshop/herren_dell1/gongnailshop/data/vo/`

**파일명**: `{Domain}Vo.kt` 또는 `{Action}{Domain}Vo.kt`

**규칙**:
- 모든 필드는 **non-nullable**
- Entity의 nullable 필드는 `.default()` 사용
- UI 포맷팅 적용 (날짜, 금액, 시간 등)
- companion object에 `Entity.mapperToVo()` 확장 함수 추가
- KDoc 주석 추가

**default() 함수들**:
- `String?.default()` → `""`
- `Int?.default()` → `0`
- `Long?.default()` → `0L`
- `Boolean?.default()` → `false`
- `List<T>?.default()` → `emptyList()`
- `Int?.idDefault()` → `-1` (ID 전용)

**예시**:
```kotlin
/**
 * 샵 영업 설정 조회 VO
 */
data class GetShopOperationSettingVo(
    val result: String,
    val operationTime: OperationTimeVo,
    val breakTimes: List<BreakTimeVo>
) {
    data class OperationTimeVo(
        val startTime: String,
        val endTime: String,
        val isActive: Boolean
    )

    data class BreakTimeVo(
        val id: Int,
        val startTime: String,
        val endTime: String
    )

    companion object {
        /**
         * Entity를 VO로 변환
         */
        fun GetShopOperationSettingEntity?.mapperToVo(): GetShopOperationSettingVo {
            return GetShopOperationSettingVo(
                result = this?.result.default(),
                operationTime = this?.operationTime.mapperToVo(),
                breakTimes = this?.breakTime.default().map { it.mapperToVo() }
            )
        }

        private fun GetShopOperationSettingEntity.OperationTimeEntity?.mapperToVo(): OperationTimeVo {
            return OperationTimeVo(
                startTime = this?.startTime.default(),
                endTime = this?.endTime.default(),
                isActive = this?.isActive.default()
            )
        }

        private fun GetShopOperationSettingEntity.BreakTimeEntity?.mapperToVo(): BreakTimeVo {
            return BreakTimeVo(
                id = this?.id.idDefault(),
                startTime = this?.startTime.default(),
                endTime = this?.endTime.default()
            )
        }
    }
}
```

### 9단계: DI 모듈 업데이트

**ServiceModule 업데이트** (새 Service 추가 시):
- 위치: `network/src/main/java/com/gongbiz/network/di/ServiceModule.kt`
- `@Provides @Singleton` 함수 추가

**RepositoryModule 업데이트** (새 Repository 추가 시):
- 위치: `network/src/main/java/com/gongbiz/network/di/RepositoryModule.kt`
- `@Binds` 함수 추가

**예시**:
```kotlin
// ServiceModule.kt
@Provides
@Singleton
fun provideShopService(
    retrofit: Retrofit
): ShopService = retrofit.create(ShopService::class.java)

// RepositoryModule.kt
@Binds
abstract fun bindShopRepository(
    impl: ShopRepositoryImpl
): ShopRepository
```

### 10단계: UseCase 생성 (선택 사항)

복잡한 비즈니스 로직이나 페이징이 필요한 경우에만 생성.

**위치**: `network/src/main/java/com/gongbiz/network/api/{domain}/usecase/`

**파일명**: `{Action}{Domain}UseCase.kt`

**규칙**:
- `UseCase` 또는 `PagingUseCase` 상속
- `@IoDispatcher` 주입
- `execute()` 메서드 구현
- `Parameters` data class 정의

### 11단계: 검증 및 요약

생성된 파일 목록을 체리님께 보고:
- ✅ Entity: `{파일 경로}`
- ✅ Body: `{파일 경로}` (있는 경우)
- ✅ Service: `{파일 경로}` (메서드 추가)
- ✅ Repository Interface: `{파일 경로}` (메서드 추가)
- ✅ Repository Impl: `{파일 경로}` (메서드 추가)
- ✅ VO: `{파일 경로}`
- ✅ DI 모듈: ServiceModule, RepositoryModule 업데이트
- ✅ UseCase: `{파일 경로}` (있는 경우)

## 핵심 규칙

### ⛔ 금지

- Entity에 기본값 설정
- Entity 필드를 non-nullable로 선언
- VO 필드를 nullable로 선언
- v2 API (ResponseBase)인데 Service가 NetworkResponse 반환
- v1 API (NetworkResponse)인데 Service가 ResponseBase 반환
- Repository Interface에서 suspend 키워드 사용 (Flow 반환 시)
- default() 함수 없이 nullable을 non-nullable로 변환
- 임의로 패키지 구조 변경
- 컨벤션 문서 무시

### ✅ 필수

- api-convention.md 전체 숙지 후 작업 시작
- **API 버전 확인**: v1인지 v2인지 확인하여 올바른 패턴 선택
- Entity: 모든 필드 nullable
- VO: 모든 필드 non-nullable + default() 사용
- **v2 API**: Service는 ResponseBase 반환, Repository는 Flow 반환
- **v1 API**: Service는 NetworkResponse 반환, Repository는 suspend fun
- KDoc 주석 추가 (클래스, 주요 함수)
- companion object에 mapperToVo() 확장 함수
- 중첩 Entity/VO도 동일한 규칙 적용
- DI 모듈 업데이트 확인
- 생성된 파일 목록 보고

## 상세 규칙

**필수 참고 문서**:
- [API 생성 컨벤션](.docs/conventions/api-convention.md) - 전체 아키텍처 및 상세 규칙
- [프로젝트 컨벤션](.docs/conventions/project-convention.md) - 네이밍 및 코드 스타일

**API 패턴 선택 기준**:

**v2 API (신규, 권장)**:
- Service: `suspend fun` + `ResponseBase<T>` 반환
- Repository Interface: `fun` + `Flow<ResponseBase<T>>` 반환
- Repository Impl: `flow { emit(service.method()) }`
- 엔드포인트: `/api/v2/...` 형태

**v1 API (기존)**:
- Service: `suspend fun` + `NetworkResponse<T, E>` 반환
- Repository Interface: `suspend fun` + `NetworkResponse<T, E>` 반환
- Repository Impl: `return service.method()`
- 엔드포인트: `/v1/...` 형태

**페이징 (버전 무관)**:
- Repository: `suspend fun` + `ResponsePaging<T>` 반환
- UseCase: `PagingUseCase` 상속

**파일 경로 패턴**:
- Entity: `network/src/main/java/com/gongbiz/network/api/{domain}/entity/`
- Body: `network/src/main/java/com/gongbiz/network/api/{domain}/body/`
- Service: `network/src/main/java/com/gongbiz/network/api/{domain}/{Domain}Service.kt`
- Repository: `network/src/main/java/com/gongbiz/network/api/{domain}/{Domain}Repository.kt`
- VO: `app/src/main/java/com/gongnailshop/herren_dell1/gongnailshop/data/vo/`
- UseCase: `network/src/main/java/com/gongbiz/network/api/{domain}/usecase/`

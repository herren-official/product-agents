---
name: b2c-android-create-api
description: B2C 프로젝트의 API 레이어 코드 자동 생성 (Service, Entity, Body, Repository interface/impl, Vo, UseCase, DI 등록). "API 만들어줘", "서비스 생성", "레포지토리 추가", "엔티티 생성" 요청 시 사용
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, AskUserQuestion
user-invocable: true
---

# API 레이어 자동 생성 (B2C)

B2C 프로젝트 멀티모듈 구조(`core:data` / `core:data-api` / `core:ui-model` / `core:domain`)에 맞춰 API 레이어를 일괄 생성한다.

**반드시 먼저 읽을 문서**: `.docs/conventions/api-convention.md`

## 핵심 규약 (요약)

- Service는 항상 `NetworkResponse<Entity, ErrorResponse>` 를 반환
- Entity는 `SuccessResponseMapper<Entity, Vo>` 를 구현하여 `mapperToVo()` 를 재정의
- RepositoryImpl 는 `suspendOnSuccess` / `suspendOnResponseWithMessage` / `onErrorMessageHandle` 로 결과 분기
- Repository interface 는 `Flow<Vo?>` 반환 (페이징은 `suspend` + `ResponsePaging<Vo?>?`)
- 인증 토큰은 Interceptor 가 자동 주입. 인증 생략 시만 `@Headers("No-Authentication: true")`
- RepositoryImpl 은 `internal class`

## 실행 단계

### 1단계: 정보 수집

`AskUserQuestion` 으로 한 번에 질문한다:

1. **도메인 이름** (예: Shop, Booking, Payment — 기존 디렉토리에 있는지 Grep 확인)
2. **API 엔드포인트 경로** (예: `/api/v1/booking/{shopId}/slots`)
3. **HTTP 메서드** (GET / POST / PUT / PATCH / DELETE)
4. **요청 파라미터** (Path / Query / Body / Header)
5. **응답 JSON 예시** 또는 필드 설명
6. **인증 필요 여부** (기본 필요. 로그인 전/공용 API 라면 "No")
7. **페이징 여부** (기본 아니오)
8. **UseCase 분리 필요 여부** (여러 Repository 조합 / 로그인 상태 병합 등이 있을 때만 Yes)

### 2단계: 프로젝트 상태 확인

```bash
# 도메인 디렉토리 존재 여부 확인
ls /Users/herren/Documents/GitHub/gongbiz-b2c-android/core/data/src/main/java/com/herren/gongb2c/data/api/
```

- 존재하면: 기존 `{Domain}Service.kt`, `{Domain}RepositoryImpl.kt`, `entity/` 에 추가
- 없으면: 새 디렉토리 생성

유사 도메인 1개를 Read 로 읽어 스타일 맞추기 (예: `booking/BookingService.kt`, `booking/BookingRepositoryImpl.kt`, `booking/entity/BookingSlotsEntity.kt`).

### 3단계: Entity 생성

**위치**: `core/data/src/main/java/com/herren/gongb2c/data/api/{domain}/entity/`

**파일명**: `{Domain}{Description}Entity.kt` (예: `BookingSlotsEntity.kt`)

**규칙**
- 모든 필드 nullable
- 중첩 타입도 nullable
- `SuccessResponseMapper<Entity, Vo>` 구현하여 `mapperToVo()` override
- 중첩 매핑은 private 확장 함수로

```kotlin
package com.herren.gongb2c.data.api.booking.entity

import com.herren.gongb2c.common.extends.default
import com.herren.gongb2c.core.ui_model.booking.vo.BookingSlotsVo
import com.herren.gongb2c.core.ui_model.core.SuccessResponseMapper

data class BookingSlotsEntity(
    val bookingAvailableSlots: List<BookingAvailableSlot>?
) : SuccessResponseMapper<BookingSlotsEntity, BookingSlotsVo> {
    data class BookingAvailableSlot(
        val date: String?,
        val isHoliday: Boolean?,
        val availableSlots: List<String>?
    )

    override fun BookingSlotsEntity?.mapperToVo() = BookingSlotsVo(
        bookingAvailableSlots = bookingAvailableSlots?.map { it.itemMapperToVo() }.default()
    )

    private fun BookingAvailableSlot?.itemMapperToVo() =
        BookingSlotsVo.BookingAvailableSlotVo(
            date = this?.date.default().convertStringToLocalDate(),
            isHoliday = this?.isHoliday.default(),
            availableSlots = this?.availableSlots.default().map { null to it.convertStringToLocalTime() }
        )
}
```

### 4단계: Vo 생성

**위치**: `core/ui-model/src/main/java/com/herren/gongb2c/core/ui_model/{domain}/vo/`

**파일명**: `{Domain}{Description}Vo.kt`

**규칙**
- 모든 필드 non-nullable
- 날짜/시간/금액은 도메인 타입(`LocalDate`, `LocalTime`, `Long`) 으로
- UI 포맷팅은 계산 프로퍼티로

```kotlin
package com.herren.gongb2c.core.ui_model.booking.vo

import java.time.LocalDate
import java.time.LocalTime

data class BookingSlotsVo(
    val bookingAvailableSlots: List<BookingAvailableSlotVo>
) {
    data class BookingAvailableSlotVo(
        val date: LocalDate,
        val isHoliday: Boolean,
        val availableSlots: List<Pair<String?, LocalTime>>,
    )
}
```

### 5단계: Body 생성 (POST/PUT/PATCH 인 경우)

**위치**: `core/ui-model/src/main/java/com/herren/gongb2c/core/ui_model/{domain}/body/`

**파일명**: `{Action}{Domain}Body.kt`

필수 필드는 non-nullable, 선택 필드는 nullable 또는 기본값.

```kotlin
package com.herren.gongb2c.core.ui_model.booking.body

data class CancelBookingBody(
    val reason: String
)
```

### 6단계: Service 작성/확장

**위치**: `core/data/src/main/java/com/herren/gongb2c/data/api/{domain}/{Domain}Service.kt`

**규칙**
- `suspend fun` + `NetworkResponse<Entity, ErrorResponse>`
- 인증 필요 없을 경우 `@Headers("No-Authentication: true")`
- Path/Query/Header 키는 `companion object` 상수로
- KDoc 주석 추가

```kotlin
package com.herren.gongb2c.data.api.booking

import com.herren.gongb2c.core.ui_model.core.ErrorResponse
import com.herren.gongb2c.core.ui_model.core.NetworkResponse
import com.herren.gongb2c.data.api.booking.entity.BookingSlotsEntity
import retrofit2.http.GET
import retrofit2.http.Headers
import retrofit2.http.Path
import retrofit2.http.Query

interface BookingService {
    /**
     * 예약 가능한 시간대 조회
     */
    @GET("/api/v1/booking/{$SHOP_ID}/{$EMPLOYEE_ID}/slots")
    @Headers("No-Authentication: true")
    suspend fun getBookingSlots(
        @Path(SHOP_ID) shopId: String,
        @Path(EMPLOYEE_ID) employeeId: Int,
        @Query(START_DATE) startDate: String,
        @Query(END_DATE) endDate: String,
        @Query(PROCEDURE_REQUIRE_TIME) procedureRequireTime: Int
    ): NetworkResponse<BookingSlotsEntity, ErrorResponse>

    companion object {
        const val SHOP_ID = "shopId"
        const val EMPLOYEE_ID = "employeeId"
        const val START_DATE = "startDate"
        const val END_DATE = "endDate"
        const val PROCEDURE_REQUIRE_TIME = "procedureRequireTime"
    }
}
```

### 7단계: Repository interface (core:data-api)

**위치**: `core/data-api/src/main/java/com/herren/gongb2c/data_api/{Domain}Repository.kt`

**규칙**
- 기존 파일이 있으면 메서드만 추가
- 단건: `fun xxx(...): Flow<Vo?>`
- 페이징: `suspend fun xxx(...): ResponsePaging<Vo?>?`
- 반환 타입은 Vo 기준, Entity 노출 금지

```kotlin
package com.herren.gongb2c.data_api

import com.herren.gongb2c.core.ui_model.booking.vo.BookingSlotsVo
import kotlinx.coroutines.flow.Flow

interface BookingRepository {
    fun getBookingSlots(
        shopId: String,
        employeeId: Int,
        startDate: String,
        endDate: String,
        procedureRequireTime: Int
    ): Flow<BookingSlotsVo?>
}
```

### 8단계: RepositoryImpl (core:data)

**위치**: `core/data/src/main/java/com/herren/gongb2c/data/api/{domain}/{Domain}RepositoryImpl.kt`

**규칙**
- `internal class ... @Inject constructor(...)`
- Service 호출 → `suspendOn*` / `onErrorMessageHandle` 로 분기
- 에러는 `throw Throwable(message)` 로 Flow 에 전파

```kotlin
package com.herren.gongb2c.data.api.booking

import com.herren.gongb2c.core.ui_model.booking.vo.BookingSlotsVo
import com.herren.gongb2c.core.ui_model.core.suspendOnResponseWithMessage
import com.herren.gongb2c.data_api.BookingRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import javax.inject.Inject

internal class BookingRepositoryImpl @Inject constructor(
    private val service: BookingService
) : BookingRepository {

    override fun getBookingSlots(
        shopId: String,
        employeeId: Int,
        startDate: String,
        endDate: String,
        procedureRequireTime: Int
    ): Flow<BookingSlotsVo?> = flow {
        service.getBookingSlots(shopId, employeeId, startDate, endDate, procedureRequireTime)
            .suspendOnResponseWithMessage(
                onSuccessResult = { emit(this) },
                onErrorMessageResult = { message -> throw Throwable(message) }
            )
    }
}
```

**NetworkResponse 확장 함수 선택 가이드**
- 단건 성공 + Vo 매핑 필요: `suspendOnResponseWithMessage`
- List 성공: `suspendOnSuccessList`
- 성공 body 없음 (`Unit` / `Any`): `suspendOnSuccessWithoutMapper { emit(Unit) }` + `onErrorMessageHandle { throw Throwable(it) }`
- 페이징: `when (val r = service.xxx())` 로 분기 후 `r.body.pagingMapperToVo()`

### 9단계: DI 등록

**ServiceModule** (`core/data/src/main/java/com/herren/gongb2c/data/di/ServiceModule.kt`) — 새 Service 인 경우만 추가:

```kotlin
@Singleton
@Provides
fun provideBookingService(
    retrofit: Retrofit
): BookingService = retrofit.newBuilder().build().create(BookingService::class.java)
```

> 인증 불필요 Service 는 `@Named("without_auth") retrofit: Retrofit` 을 주입받고 `@Named("without_auth")` 어노테이션 추가. (`WithoutAuthModule.kt` 참조)

**RepositoryModule** (`core/data/src/main/java/com/herren/gongb2c/data/di/RepositoryModule.kt`) — 새 Repository 인 경우만 추가:

```kotlin
@Binds
@Singleton
abstract fun bindBookingRepository(
    impl: BookingRepositoryImpl
): BookingRepository
```

### 10단계: UseCase 작성 (선택)

여러 Repository 조합 / 로그인 상태 병합 / 복합 변환이 있을 때만 작성.

**위치**: `core/domain/src/main/java/com/herren/gongb2c/domain/` 또는 `.domain/{domain}/`

**파일명**: `{Action}{Domain}UseCase.kt`

```kotlin
package com.herren.gongb2c.domain

import com.herren.gongb2c.core.ui_model.booking.vo.BookingHistoryVo
import com.herren.gongb2c.data_api.BookingRepository
import com.herren.gongb2c.data_api.UserRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import javax.inject.Inject

class FetchBookingHistoryUseCase @Inject constructor(
    private val userRepository: UserRepository,
    private val bookingRepository: BookingRepository
) {
    data class Parameters(val filter: String, val offset: Int = 0, val size: Int = 10)
    data class Data(val isLoggedIn: Boolean, val history: ResponsePaging<BookingHistoryVo?>?)

    operator fun invoke(parameters: Parameters): Flow<Result<Data>> = flow {
        val isLoggedIn = userRepository.isLoggedIn()
        val history = bookingRepository.getBookingHistory(parameters.filter, parameters.offset, parameters.size)
        emit(Result.success(Data(isLoggedIn, history)))
    }.catch { e ->
        emit(Result.failure(e))
    }.flowOn(Dispatchers.IO)
}
```

**UseCase 기반 클래스 / `@IoDispatcher` 주입 패턴을 사용하지 않는다.** B2C는 직접 `flowOn(Dispatchers.IO)` 를 사용한다.

### 11단계: 검증 및 요약

생성된 파일 목록을 다나님께 보고:
- Entity: `{경로}`
- Vo: `{경로}`
- Body: `{경로}` (해당 시)
- Service: `{경로}` (신규 또는 메서드 추가)
- Repository interface: `{경로}`
- RepositoryImpl: `{경로}`
- UseCase: `{경로}` (해당 시)
- DI 등록: ServiceModule / RepositoryModule 업데이트 (해당 시)

마지막으로 빌드 확인 제안: `./gradlew :core:data:compileDevDebugKotlin :core:data-api:compileDevDebugKotlin --continue`

## 핵심 규칙

### 금지
- Repository 반환 타입에 `ResponseBase<T>` 사용 — B2C는 쓰지 않음
- Entity 필드를 non-nullable 로 선언
- Vo 필드를 nullable 로 선언
- Service 에 토큰 파라미터 추가 — Interceptor 가 처리
- RepositoryImpl 을 `public` 으로 선언 — 반드시 `internal`
- UseCase 에서 `UseCase` / `PagingUseCase` 베이스 클래스 상속 — B2C는 베이스 클래스 없음
- 모듈 경로 임의 변경

### 필수
- `.docs/conventions/api-convention.md` 규칙 전수 준수
- Entity 는 `SuccessResponseMapper<Entity, Vo>` 구현 + `mapperToVo()` override
- Vo 는 Entity 패키지에서 import (순환 의존 주의)
- RepositoryImpl 의 에러는 Flow 에러로 전파 (`throw Throwable(message)`)
- DI 등록 확인
- 유사 도메인 (booking, home, shop 등) 스타일 따르기

## 참고 문서

- [API 컨벤션](../../.docs/conventions/api-convention.md)
- [프로젝트 컨벤션](../../.docs/conventions/project-convention.md)
- [String 리소스 컨벤션](../../.docs/conventions/string-resource-convention.md) — 에러 메시지 문자열 추가 시

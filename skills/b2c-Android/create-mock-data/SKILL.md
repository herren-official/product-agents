---
name: b2c-android-create-mock-data
description: B2C 테스트용 MockWebServer JSON fixture 자동 생성. Service 엔드포인트 분석 후 feature 모듈의 src/test/resources/{domain}/ 에 규격화된 파일명으로 생성. "목 데이터 만들어줘", "mock 데이터 생성", "테스트 데이터", "목 파일 추가", "mock json" 요청 시 사용
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, AskUserQuestion
user-invocable: true
---

# Mock JSON 데이터 자동 생성 (B2C)

B2C는 `MockWebServer.dispatchResponse()` 가 **파일명 규칙**을 통해 요청 URL에 자동 매핑하여 응답을 반환한다. 이 스킬은 해당 규칙에 맞는 JSON fixture 를 생성한다.

**반드시 먼저 읽을 문서**:
- `.docs/conventions/api-convention.md` — Service/Entity 구조 이해
- `.docs/conventions/test-convention.md` — MockWebServer 사용법
- `.docs/test/mock-patterns.md` — Mock 패턴

## 실행 단계

### 1단계: 정보 수집

필요 정보 (Service 파일을 Read 해서 자동 추출하거나, 없으면 `AskUserQuestion` 으로 질의):

1. **대상 Service + 메서드** (예: `ShopService.getShopInfo`)
2. **HTTP 메서드** (GET/POST/PUT/PATCH/DELETE)
3. **엔드포인트 경로** (어노테이션 값 그대로, Path 파라미터 포함)
4. **Path 값 치환** (예: `{shopId}` → `S000003969`)
5. **Query 파라미터** (key=value 형태)
6. **사용 feature 모듈** (예: `feature/shop-detail` → `feature:shop-detail/src/test/resources/`)
7. **시나리오**:
   - `success` (200 성공, 기본값)
   - `apiError` (500 API 에러)
   - `apiNotSuccess` (200 이지만 result: false)
   - `empty` (빈 데이터)
   - `failAuth` (401)

### 2단계: 저장 경로 결정

**feature 모듈 선택 규칙**: 해당 Service 를 테스트하는 feature 모듈. 확실치 않으면 `AskUserQuestion`.

```
feature/{module}/src/test/resources/{domain}/{fileName}.json
```

**domain 폴더** — `JsonInterceptor.kt` 의 `getDomainFolder()` 매핑을 따른다:

| URL 포함 | 폴더 |
|---------|------|
| `coupon` | `coupon` |
| `image` | `image` |
| `review` | `review` |
| `search` | `search` |
| `user` | `user` |
| `shop` | `shop` |
| `terms` | `terms` |
| `auth` | `auth` |
| `booking` | `booking` |
| `verification` | `verification` |
| `cok` | `cok` |
| `main` | `main` |
| `curation` | `curation` |
| `magazine` | `magazine` |
| `app-push` | `appPush` |
| 기타 | `b2c` |

### 3단계: 파일명 생성 (규칙 엄수)

`MockWebServerExtension.dispatchResponse()` 는 아래 규칙으로 파일을 찾는다. **완전히 일치해야** 매칭된다.

```
{method_lowercase}_{path_segments_joined_by_underscore}_{query_params_joined}_{statusCode}_{apiResult}.json
```

#### 변환 규칙
- HTTP 메서드: 소문자 (`get`, `post`, `put`, `patch`, `delete`)
- URL path: `/` 를 `_` 로 치환, 선행 `_` 제거
- path 내 `.` 과 `:` 는 `_` 로 치환
- query string: `key=value` 를 `_` 로 연결. `mock`, `mockCode`, `mockApiResult` 는 제외
- 상태 코드: `200`, `400`, `500` 등
- apiResult: `success`, `apiError`, `apiNotSuccess`, `failAuth`, `empty`

#### 예시

| Service 어노테이션 | 실제 URL | 파일명 |
|------------------|---------|-------|
| `@GET("/api/v1/shop/{shopId}")` with shopId=S000003969 | `/api/v1/shop/S000003969` | `get_api_v1_shop_S000003969_200_success.json` |
| `@GET("/api/v1/review")` with `?shopId=S000003969` | `/api/v1/review?shopId=S000003969` | `get_api_v1_review_shopId=S000003969_200_success.json` |
| `@GET("/api/v2/business-day/employees/{seq}")` seq=2 | `/api/v2/business-day/employees/2` | `get_api_v2_business-day_employees_2_200_success.json` |
| `@POST("/api/v1/booking/temporary-create")` | `/api/v1/booking/temporary-create` | `post_api_v1_booking_temporary-create_200_success.json` |

### 4단계: JSON 본문 생성

1. **대응 Entity 를 Read** 하여 필드 구조 파악
2. Entity 는 모든 필드가 nullable 이지만, 정상 성공 응답은 **실제 서비스와 유사한 값**으로 채워준다
3. 중첩 Entity 도 동일하게 전개
4. 동적 값 처리:
   - 포트: `http://__PORT__/...` 사용 (런타임에 MockWebServer 포트로 치환됨)
   - 날짜: `2024-01-01T00:00:00`, `2024-01-01` 등 실제 포맷 준수
   - ID: 숫자형 ID 사용 (예: `1`, `123`)

#### JSON 예시 (성공)

Entity:
```kotlin
data class BookingSlotsEntity(
    val bookingAvailableSlots: List<BookingAvailableSlot>?
) {
    data class BookingAvailableSlot(
        val date: String?,
        val isHoliday: Boolean?,
        val availableSlots: List<String>?
    )
}
```

JSON (`get_api_v1_booking_S000003969_1_slots_startDate=2024-01-01_endDate=2024-01-07_procedureRequireTime=60_200_success.json`):
```json
{
  "bookingAvailableSlots": [
    {
      "date": "2024-01-01",
      "isHoliday": false,
      "availableSlots": ["10:00", "10:30", "11:00", "14:00"]
    },
    {
      "date": "2024-01-02",
      "isHoliday": true,
      "availableSlots": []
    }
  ]
}
```

#### JSON 예시 (apiError — 500)

```json
{
  "timestamp": "2024-01-01T00:00:00",
  "status": 500,
  "code": "E_INTERNAL",
  "message": "일시적인 오류가 발생했어요."
}
```

### 5단계: 공용 응답 파일 확인

공용 시나리오 파일은 feature 모듈 `src/test/resources/` 루트에 이미 존재할 수 있다. 없으면 생성한다:

| 파일 | 용도 | 내용 |
|------|-----|------|
| `called_api_success.json` | `apiResult: true` 기본 래퍼 | `{"apiResult": true, "data": null}` |
| `called_api_not_success.json` | `apiResult: false` | `{"apiResult": false, "message": "실패"}` |
| `called_api_error.json` | 500 에러 | `{"timestamp": "...", "status": 500, "code": "E_INTERNAL", "message": "..."}` |
| `called_api_fail_auth.json` | 401 인증 만료 | `{"timestamp": "...", "status": 401, "code": "E_UNAUTHORIZED", "message": "..."}` |
| `called_empty_data.json` | 빈 데이터 | `{"data": null}` 또는 `[]` |
| `called_204.json` | 204 No Content | `{}` |
| `called_401.json` | 401 Unauthorized | `{"timestamp": "...", "status": 401, "code": "E_UNAUTHORIZED", "message": "..."}` |

이미 존재하면 재사용. 없으면 생성 후 `AskUserQuestion` 으로 내용 검토 요청.

### 6단계: 파일 생성 및 확인

```bash
# 디렉토리 생성 (없으면)
mkdir -p /Users/herren/Documents/GitHub/gongbiz-b2c-android/feature/{module}/src/test/resources/{domain}/

# Write 로 JSON 생성
```

생성 후 다른 같은 폴더 JSON 과 포맷 정합성 (들여쓰기, 쌍따옴표 등) 을 1개 샘플과 비교한다.

### 7단계: 테스트 연동 가이드 (선택)

사용자가 요청하면 해당 모듈의 ViewModel 테스트에서 이 fixture 를 사용하는 코드 예시를 제시:

```kotlin
@BeforeEach
override fun setUp(mainCoroutineExtension: MainCoroutineExtension) {
    super.setUp(mainCoroutineExtension)
    shopService = MockWebServerService.createService<ShopService>(mockWebServer)
    mockWebServer.dispatchResponse()   // 기본: 200 + success JSON 자동 매칭
}

// 에러 시나리오
@Test
fun `API 에러 시 SideEffect 발행`() = runTest(coroutineExtension.testDispatcher) {
    mockWebServer.dispatchResponse(code = "500", apiResult = "apiError")
    // ... (→ called_api_error.json 사용)
}
```

### 8단계: 결과 보고

```
생성 완료: {fileName}

경로: feature/{module}/src/test/resources/{domain}/{fileName}.json
시나리오: {success/apiError/empty ...}
매칭 URL: {http method} {endpoint}

사용:
  mockWebServer.dispatchResponse(code = "{code}", apiResult = "{apiResult}")
```

## 핵심 규칙

### 필수
- 파일명은 `JsonInterceptor.getFormattedFileName()` 규칙과 **완전 일치** — 한 글자 틀리면 매칭 실패
- domain 폴더는 `getDomainFolder()` 매핑 따르기 (URL 키워드 기반)
- 실제 Entity 구조와 필드명/타입 일치 (nullable 허용)
- 포트 치환이 필요한 URL 은 `__PORT__` 사용 (예: `"imageUrl": "http://__PORT__/image/abc.png"`)
- 쿼리 파라미터 순서는 URL 에 나타난 순서대로

### 금지
- 파일명에 공백/대문자/특수문자 (`?`, `&`, `=` 는 query 구분용으로만)
- 임의로 `data` wrapper 추가 (Entity 가 래핑하지 않으면 그대로)
- mock JSON 에 실제 사용자 개인정보 삽입
- `src/main/` 하위에 저장 (반드시 `src/test/resources/`)

## 참고 파일

- 디스패처 구현: `core/testing/src/testFixtures/kotlin/MockWebServerExtension.kt`
- 파일명 규칙: `core/data/src/main/java/com/herren/gongb2c/data/core/JsonInterceptor.kt` (`getApiResultFile`, `getFormattedFileName`, `getDomainFolder`)
- 실 사용 예시: `feature/shop-detail/src/test/resources/shop/get_api_v1_shop_S000003969_200_success.json`

## 관련 스킬

- [create-api](../create-api/SKILL.md) — API 레이어 생성 후 이 스킬로 mock 데이터 작성 권장

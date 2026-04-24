---
name: b2b-android-create-mock-data
description: API Mock 데이터 JSON 파일 자동 생성. "목 데이터 만들어줘", "mock 데이터 생성", "테스트 데이터", "목 파일 추가", "mock json" 요청 시 사용
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, AskUserQuestion
user-invocable: true
---

# Mock 데이터 자동 생성 스킬

API 테스트와 개발을 위한 Mock JSON 파일을 프로젝트 컨벤션에 맞게 자동 생성합니다.

## 실행 단계

### 1단계: API 정보 수집

사용자에게 다음 정보를 질문으로 수집:

1. **대상 API 선택**
   - 기존 Service 메서드 선택 (경로 제공 시)
     - **중요**: Service 메서드를 읽어서 `isMock` 파라미터 존재 여부 확인
   - 또는 수동 입력 (HTTP Method, Endpoint, 파라미터)

2. **HTTP 메서드** (GET, POST, PUT, PATCH, DELETE)

3. **API 엔드포인트** (예: `/api/v2/shops/{shopNo}/business-day`)
   - Path 파라미터 포함 시 실제 예시 값 요청 (예: shopNo=S000003194)

4. **Query 파라미터** (선택적)
   - 예: `page=0`, `size=10`, `startDate=2024-01-01`

5. **응답 시나리오** (기본값: 성공 응답)
   - 응답 코드: 200, 201, 204, 400, 404, 500 등
   - API Result 타입: success, apiError, apiNotSuccess, failAuth, emptyData
   - Account ID: herrenail (기본값)

6. **Entity 타입** (응답 구조)
   - Entity 클래스 경로 제공 시 자동 분석
   - 또는 수동으로 응답 구조 입력

### 2단계: 파일명 생성 규칙 적용

JsonInterceptor의 네이밍 규칙을 정확히 따름:

**패턴**:
```
{method}_{url_path}_{query_params}_{response_code}_{api_result}_{account}.json
```

**각 구성 요소 변환**:

1. **HTTP Method**: 소문자 변환 (`GET` → `get`)

2. **URL Path**: 슬래시를 언더바로 변환
   - `/api/v2/shops/{shopNo}/business-day` → `api_v2_shops_{shopNo}_business-day`
   - Path 파라미터는 실제 값으로 치환 (`{shopNo}` → `S000003194`)
   - 하이픈(`-`)은 그대로 유지

3. **Query 파라미터**: `key=value` 형식으로 언더바 연결
   - 없으면 생략
   - 있으면: `page=0&size=10` → `_page=0_size=10`
   - 빈 값도 포함: `customerName=&page=20` → `_customerName=_page=20`

4. **Response Code**: 숫자 그대로 (`200`, `404`)

5. **API Result**:
   - `success` (기본값, 정상 응답)
   - `apiError` (API 오류)
   - `apiNotSuccess` (API 실패)
   - `failAuth` (인증 실패)
   - `emptyData` (빈 데이터)
   - `etc` (기타)

6. **Account**: `herrenail` (기본값, 고정)

**생성 예시**:
```
API: GET /api/v2/shops/S000003194/business-day
→ get_api_v2_shops_S000003194_business-day_200_success_herrenail.json

API: GET /api/v2/booking_payments?page=0&size=10
→ get_api_v2_booking_payments_page=0_size=10_200_success_herrenail.json

API: GET /api/v2/statistics/sales/items?startDate=2024-01-01&endDate=2024-12-31
→ get_api_v2_statistics_sales_items_startDate=2024-01-01_endDate=2024-12-31_200_success_herrenail.json

API: POST /api/v2/customer (404 에러)
→ post_api_v2_customer_404_etc_herrenail.json
```

### 3단계: 저장 디렉토리 결정 및 도메인 등록

**두 가지 저장 위치**:

1. **프로덕션 빌드 리소스** (실제 앱 포함)
   - 경로: `network/src/main/resources/{domain}/`
   - 사용: 운영 환경에서 필요한 Mock 데이터
   - 드물게 사용

2. **테스트 Fixtures 리소스** (테스트 전용, 권장)
   - 경로: `network/src/testFixtures/resources/{domain}/`
   - 사용: 단위 테스트, 통합 테스트용 Mock 데이터
   - 기본 선택지

**도메인 폴더 결정 프로세스**:

1. **JsonInterceptor.kt 파일 읽기**
   - 위치: `network/src/main/java/com/gongbiz/network/base/JsonInterceptor.kt`
   - `getDomainFolder` 함수 확인

2. **도메인 추출**
   - URL path에서 도메인 추출 (예: `/api/v2/business-day/shop` → `business-day`)
   - 추출 규칙:
     - `api`, `v1`, `v2` 등 버전 정보 제외
     - 첫 번째 의미있는 세그먼트 사용
     - 추출 불가능한 경우: `unknown`

3. **등록 여부 확인**
   - `getDomainFolder` 함수의 `contains("{도메인}")` 분기 존재 여부 확인
   - 예: `contains("business-day") -> "business-day"` 있는지 확인

4. **등록되지 않은 도메인 처리** (중요!)
   - **JsonInterceptor.kt 수정**: `getDomainFolder` 함수에 새 도메인 추가
   - **폴더 생성**: `network/src/testFixtures/resources/{도메인}/` 생성
   - **체리님께 보고**: 새 도메인 등록 완료

**JsonInterceptor.kt 수정 방법**:

```kotlin
// Before (도메인 없음)
private fun getDomainFolder(path: String): String {
    with(path) {
        return when {
            contains("booking/payments") -> "booking_payments"
            contains("shop") -> "shop"
            // ...
            contains("statistics") -> "statistics"
            else -> "unknown"
        }
    }
}

// After (business-day 도메인 추가)
private fun getDomainFolder(path: String): String {
    with(path) {
        return when {
            contains("booking/payments") -> "booking_payments"
            contains("shop") -> "shop"
            // ...
            contains("statistics") -> "statistics"
            contains("business-day") -> "business-day"  // ✅ 추가
            else -> "unknown"
        }
    }
}
```

**기존 등록된 도메인**:

| URL 포함 경로 | 도메인 폴더 |
|---------------|------------|
| `booking/payments` | `booking_payments/` |
| `booking/payment` | `booking_payments/` |
| `shop` | `shop/` |
| `employees` | `employee/` |
| `customer`, `cust` | `customer/` |
| `users` | `users/` |
| `booking-deposit` | `booking-deposit/` |
| `sale` | `sale/` |
| `notifications` | `notifications/` |
| `settlement` | `settlement/` |
| `statistics` | `statistics/` |
| `login` | `login/` |
| `membership` | `membership/` |
| `point` | `point/` |
| `business-day` | `business-day/` |

**예시**:
```
API: /api/v2/shops/S000003194/business-day
→ 도메인 추출: business-day
→ JsonInterceptor 확인: contains("business-day") 있음 ✅
→ 최종 경로: network/src/testFixtures/resources/business-day/

API: /api/v2/payment-methods (새 도메인)
→ 도메인 추출: payment-methods
→ JsonInterceptor 확인: contains("payment-methods") 없음 ⚠️
→ JsonInterceptor.kt 수정: contains("payment-methods") -> "payment-methods" 추가
→ 폴더 생성: network/src/testFixtures/resources/payment-methods/
→ 체리님께 보고: "✅ 새 도메인 등록: payment-methods"
```

### 4단계: JSON 샘플 데이터 생성

**시나리오별 JSON 구조**:

#### A. 정상 응답 (200, success)

**단일 객체 응답**:
```json
{
  "data": {
    "shopNo": "S000003194",
    "timeUnit": 30,
    "isUsedNoManager": false,
    "isUsedGroupBooking": true,
    "businessDays": [
      {
        "day": "MONDAY",
        "activation": true,
        "startTime": "09:00",
        "endTime": "18:00",
        "restTimes": [
          {
            "startTime": "12:00",
            "endTime": "13:00"
          }
        ]
      }
    ]
  }
}
```

**페이징 응답** (ResponsePaging):
```json
{
  "data": {
    "content": [
      {
        "id": 1,
        "name": "샘플 데이터"
      }
    ],
    "pageable": {
      "pageNumber": 0,
      "pageSize": 10,
      "sort": {
        "sorted": false,
        "unsorted": true,
        "empty": true
      },
      "offset": 0,
      "paged": true,
      "unpaged": false
    },
    "totalElements": 1,
    "totalPages": 1,
    "last": true,
    "size": 10,
    "number": 0,
    "sort": {
      "sorted": false,
      "unsorted": true,
      "empty": true
    },
    "numberOfElements": 1,
    "first": true,
    "empty": false
  },
  "errorResponse": null
}
```

**빈 데이터 응답** (204, emptyData):
```json
{}
```

#### B. 에러 응답

**API 오류 (apiError)**:
```json
{
  "timestamp": "2025-01-27 12:00:00",
  "status": 500,
  "message": "Internal Server Error",
  "code": "ERR_INTERNAL",
  "errors": null
}
```

**인증 실패 (failAuth)**:
```json
{
  "timestamp": "2025-01-27 12:00:00",
  "status": 401,
  "message": "Unauthorized",
  "code": "ERR_AUTH_FAILED",
  "errors": null
}
```

**API 실패 (apiNotSuccess)**:
```json
{
  "data": null,
  "errorResponse": {
    "timestamp": "2025-01-27 12:00:00",
    "status": 400,
    "message": "Bad Request",
    "code": "ERR_INVALID_PARAM",
    "errors": [
      {
        "field": "shopNo",
        "value": "",
        "reason": "필수 값입니다."
      }
    ]
  }
}
```

**샘플 데이터 생성 규칙**:

1. **Entity 구조 분석**
   - Entity 클래스 경로가 제공되면 Read 도구로 읽기
   - 필드 타입에 맞는 샘플 값 생성:
     - `String`: 의미있는 샘플 문자열 (`"S000003194"`, `"MONDAY"`)
     - `Int`, `Long`: 적절한 숫자 (`30`, `1000`)
     - `Boolean`: `true` 또는 `false`
     - `List`: 1-2개 샘플 요소 포함
     - 중첩 객체: 재귀적으로 샘플 생성

2. **시간/날짜 포맷**
   - 날짜: `"2024-01-27"` (yyyy-MM-dd)
   - 시간: `"09:00"` (HH:mm)
   - 타임스탬프: `"2025-01-27 12:00:00"` (yyyy-MM-dd HH:mm:ss)

3. **비즈니스 도메인 샘플**
   - shopNo: `"S000003194"`
   - customerNo: `24138`
   - employeeNo: `12345`
   - 요일: `"MONDAY"`, `"TUESDAY"` 등

### 5단계: 공용 응답 파일 확인

**공용 응답 파일은 생성하지 않음** (이미 존재):

- `called_api_error.json` (apiError)
- `called_api_success.json` (apiSuccess)
- `called_api_not_success.json` (apiNotSuccess)
- `called_api_fail_auth.json` (failAuth)
- `called_empty_data.json` (emptyData)
- `called_204.json` (204 No Content)

**API Result가 위 타입이면**:
- 사용자에게 "공용 응답 파일이 이미 존재합니다" 알림
- 별도 파일 생성 불필요

**API Result가 success 또는 etc이면**:
- 도메인별 폴더에 파일 생성 필요

### 6단계: Service 메서드에 isMock 파라미터 추가

Mock 데이터를 사용하려면 **Service 메서드에 `isMock` 파라미터가 반드시 필요**합니다.

**확인 사항**:
1. 대상 Service 메서드 읽기
2. `@Query(JsonInterceptor.MOCK) isMock: Boolean` 파라미터 존재 여부 확인

**파라미터가 없으면 추가**:

**추가 전**:
```kotlin
@GET("api/v2/business-day/shop")
suspend fun getShopBusinessDay(
    @Header(GD_AUTH_TOKEN) token: String
): ResponseBase<GetShopBusinessDayEntity>
```

**추가 후**:
```kotlin
import com.gongbiz.network.base.JsonInterceptor

@GET("api/v2/business-day/shop")
suspend fun getShopBusinessDay(
    @Header(GD_AUTH_TOKEN) token: String,
    @Query(JsonInterceptor.MOCK) isMock: Boolean = false
): ResponseBase<GetShopBusinessDayEntity>
```

**규칙**:
- `JsonInterceptor` import 추가 필요
- 기본값은 `false` (프로덕션 안전)
- KDoc에 `@param isMock Mock 데이터 사용 여부 (DEBUG 빌드 전용)` 추가

**파라미터가 이미 있으면**:
- Skip (수정 불필요)

### 7단계: 파일 생성 및 확인

1. **디렉토리 생성** (존재하지 않으면)
   ```bash
   mkdir -p network/src/testFixtures/resources/{domain}
   ```

2. **JSON 파일 작성**
   - Write 도구 사용
   - 들여쓰기: 2칸 스페이스
   - UTF-8 인코딩

3. **생성 완료 보고**
   - Service 수정 사항 (isMock 파라미터 추가 여부)
   - 파일 경로 출력
   - 파일명 규칙 설명
   - Service에서 사용 방법 안내

### 8단계: Service 메서드 사용 가이드 (선택적)

**Mock 데이터 사용 방법 안내**:

```kotlin
// 실제 API 호출 (기본값)
val response = service.getShopBusinessDay(
    token = "token"
)
// → URL: /api/v2/business-day/shop (실제 서버)

// Mock 데이터 사용 (DEBUG 빌드)
val response = service.getShopBusinessDay(
    token = "token",
    isMock = true
)
// → URL: /api/v2/business-day/shop?mock=true
// → Mock 파일: get_api_v2_business-day_shop_200_success_herrenail.json

// 특정 응답 시나리오 테스트 (URL에 추가 파라미터)
// mockCode, mockApiResult는 URL에 직접 추가 필요
// 예: ?mock=true&mockCode=404&mockApiResult=etc
```

**JsonInterceptor 작동 조건**:
- DEBUG 빌드에서만 작동
- Service 메서드에 `isMock` 파라미터 필요
- URL에 `mock=true` 쿼리 파라미터 포함 시
- 기본값: mockCode=200, mockApiResult=success, mockAccount=herrenail

### 9단계: 검증 및 요약

생성된 파일 정보를 체리님께 보고:

```
✅ Mock 데이터 생성 완료

📝 Service 수정:
   - 파일: network/src/main/java/com/gongbiz/network/api/shop/ShopService.kt
   - 수정: getShopBusinessDay 메서드에 isMock 파라미터 추가
   - Import: com.gongbiz.network.base.JsonInterceptor 추가

🆕 도메인 등록 (새 도메인인 경우):
   - 파일: network/src/main/java/com/gongbiz/network/base/JsonInterceptor.kt
   - 수정: getDomainFolder 함수에 contains("business-day") -> "business-day" 추가
   - 폴더 생성: network/src/testFixtures/resources/business-day/

📁 Mock 파일 경로:
   network/src/testFixtures/resources/business-day/get_api_v2_business-day_shop_200_success_herrenail.json

📋 파일명 구조:
   - HTTP Method: get
   - URL Path: api_v2_business-day_shop
   - Query Params: (없음)
   - Response Code: 200
   - API Result: success
   - Account: herrenail

🔍 사용 방법:
   service.getShopBusinessDay(
       token = "token",
       isMock = true
   )
   → GET /api/v2/business-day/shop?mock=true

💡 추가 시나리오:
   - 에러 응답: mockCode=404&mockApiResult=etc
   - 인증 실패: mockCode=401&mockApiResult=failAuth
   - 빈 데이터: mockCode=204&mockApiResult=emptyData
```

## 핵심 규칙

### ⛔ 금지

- Service에 isMock 파라미터 추가하지 않고 Mock 파일만 생성
- isMock 기본값을 `true`로 설정 (반드시 `false`)
- **새 도메인을 JsonInterceptor.kt에 등록하지 않고 unknown 폴더 사용**
- 파일명 규칙을 임의로 변경
- URL Path의 하이픈(`-`)을 언더바(`_`)로 변경 (하이픈 유지)
- 슬래시(`/`)를 하이픈(`-`)으로 변경 (언더바 `_` 사용)
- Query 파라미터에서 mock 관련 파라미터 포함 (mock, mockCode, mockApiResult, mockAccount 제외)
- 공용 응답 파일 덮어쓰기 (called_*.json)
- Entity 필드와 다른 구조의 JSON 생성
- 프로덕션 리소스에 테스트 데이터 저장 (기본적으로 testFixtures 사용)

### ✅ 필수

- **Service 메서드에 isMock 파라미터 추가 확인** (없으면 추가)
- JsonInterceptor import 추가 (`import com.gongbiz.network.base.JsonInterceptor`)
- isMock 기본값은 `false`로 설정
- **등록되지 않은 도메인 처리**:
  - JsonInterceptor.kt의 `getDomainFolder` 함수에 `contains` 분기 추가
  - 해당 도메인 폴더 생성
  - 체리님께 명확히 보고
- JsonInterceptor 파일명 규칙 정확히 준수
- Entity 구조 분석 후 JSON 생성
- 의미있는 샘플 데이터 사용 (랜덤 값 지양)
- 페이징 응답 시 pageable 구조 포함
- 에러 응답 시 errorResponse 구조 포함
- JSON 들여쓰기 2칸 스페이스
- UTF-8 인코딩
- Service 수정, 도메인 등록, 파일 경로를 명확히 보고

## 상세 규칙

**필수 참고 코드**:
- [JsonInterceptor.kt](network/src/main/java/com/gongbiz/network/base/JsonInterceptor.kt) - Mock 데이터 로딩 메커니즘
- 기존 Mock 데이터 파일들: `network/src/testFixtures/resources/` - 샘플 참고

**파일명 생성 알고리즘** (JsonInterceptor lines 48-101 참고):
1. HTTP Method를 소문자로 변환
2. URL Path를 `/`로 split
3. 각 Path 세그먼트를 `_`로 연결
4. Path 파라미터 `{}`를 실제 값으로 치환
5. Query 파라미터를 `key=value` 형식으로 `_` 연결
6. Response Code, API Result, Account를 `_`로 연결
7. `.json` 확장자 추가

**도메인 폴더 결정 로직** (JsonInterceptor getDomainFolder):
- URL Path에 특정 키워드 포함 여부로 판단
- `contains()` 함수로 부분 일치 검사
- 우선순위: booking/payments > shop > employees > customer > ... > unknown(기본값)
- **등록되지 않은 도메인 처리**:
  1. URL에서 도메인 추출 (`api`, `v1`, `v2` 제외)
  2. JsonInterceptor.kt의 `getDomainFolder`에 `contains` 분기 추가
  3. 폴더 생성
  4. 체리님께 보고

**Entity 분석 패턴**:
- data class 필드 추출
- nullable (`?`) 필드는 non-null 샘플 생성
- List 타입은 1-2개 요소 배열
- 중첩 data class는 재귀 분석

**JSON 샘플 품질 기준**:
- 실제 사용 가능한 값 (예: shopNo="S000003194")
- 비즈니스 도메인 이해 반영 (예: 요일은 "MONDAY", 시간은 "09:00")
- 최소한의 샘플 데이터 (과도한 배열 요소 지양)
- 테스트 시나리오를 고려한 값 (예: 엣지 케이스, 경계값)

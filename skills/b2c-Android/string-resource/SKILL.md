---
name: b2c-android-string-resource
description: B2C 프로젝트에 문자열 리소스 추가. feature 모듈별 strings.xml 배치 + 컨벤션 기반 네이밍. "문자열 추가", "string resource", "텍스트 추가", "strings.xml" 요청 시 사용
allowed-tools: Bash, Read, Write, Edit, Grep, Glob
user-invocable: true
---

# String Resource 스킬 (B2C)

B2C 멀티모듈 구조에 맞게 strings.xml 에 문자열을 추가한다.

**반드시 먼저 읽을 문서**: `.docs/conventions/string-resource-convention.md`

## 핵심 규약 (요약)

- snake_case, 계층 구조 `{feature}_{screen}_{purpose}`
- feature 모듈별로 `feature/{name}/src/main/res/values/strings.xml` 에 배치
- 여러 feature 가 공유하면 `core/common/src/main/res/values/strings.xml`
- 공통 액션은 `core:common` 으로 승격 (단, 이미 존재하는 중복부터 제거 후)
- 하드코딩 금지 — Compose `Text("...")` 대신 `stringResource(R.string.xxx)`

## 실행 단계

### 1단계: 컨벤션 확인

`.docs/conventions/string-resource-convention.md` 를 한 번만 읽어 규칙 숙지 (도메인 prefix 표 확인).

### 2단계: 배치 대상 모듈 결정

사용 화면/컴포넌트를 파악해 배치 모듈을 결정:

| 사용 범위 | 위치 |
|---------|------|
| 특정 feature 내부만 | `feature/{name}/src/main/res/values/strings.xml` |
| 여러 feature 공유 | `core/common/src/main/res/values/strings.xml` |
| 디자인 시스템 컴포넌트 전용 | `core/designsystem-v2/src/main/res/values/strings.xml` |
| 푸시 채널/앱 레벨 | `core/notification/...` 또는 `app/src/main/res/values/strings.xml` |

사용자가 특정 파일/화면을 언급했다면 그 화면의 모듈 경로로 추론한다. 명시가 없으면 `AskUserQuestion` 으로 배치 모듈 확인.

### 3단계: 중복 확인

```bash
# 전체 모듈에서 유사 key 검색
grep -rn 'name="{keyword}' --include='strings.xml' /Users/herren/Documents/GitHub/gongbiz-b2c-android
```

이미 존재하면 재사용하고 사용자에게 알린다.

### 4단계: 네이밍 결정

- feature prefix: 컨벤션 문서의 도메인 키워드 표 참조 (`home_*`, `mypage_*`, `shop_detail_*`, `booking_*`, `payment_*`, `cok_*`, `magazine_*`, `curation_*`, `around_me_*`, `alarm_*`, `shop_news_*`, `review_*`, `coupon_*`, `dev_*`, `login_*`)
- screen 단위 sub-prefix 포함
- purpose 접미사:

| 용도 | 접미사 | 예시 |
|------|-------|------|
| 화면 제목 | `_title` | `home_recommend_title` |
| 부가 설명 | `_description` / `_sub` | `alarm_setting_device_off_description` |
| 액션 버튼 | `_action` | `mypage_login_action` |
| 입력 힌트 | `_hint` | `search_input_hint` |
| 다이얼로그 제목/본문 | `_dialog_title` / `_dialog_description` | `booking_cancel_dialog_title` |
| 토스트 | `_toast` / `toast_{action}` | `payment_bill_download_toast` |
| 에러 메시지 | `_error_{type}` | `payment_error_unsupported_method` |
| 지원 텍스트 | `_supporting` | `sign_up_id_supporting` |

### 5단계: strings.xml 에 추가

Edit 으로 타겟 파일에 추가. 섹션 주석으로 그룹핑:

```xml
<resources>

    <!-- 기존 섹션... -->

    <!-- 결제 빌 상세 -->
    <string name="payment_bill_download_action">영수증 다운로드</string>
    <string name="payment_bill_download_toast">영수증이 저장되었어요.</string>
    <string name="payment_bill_cancel_dialog_title">결제 취소</string>
    <string name="payment_bill_cancel_dialog_description">결제를 정말 취소하시겠어요?</string>

</resources>
```

**포맷 문자열** 은 placeholder 표기 엄수:
- 단일 치환: `%s` (String), `%d` (Int)
- 어순 변경 필요: `%1$s`, `%2$d`
- 금액: `%,d원` / 퍼센트: `%d%%`
- HTML 포함: `<![CDATA[ ... ]]>`
- 번역 제외: `translatable="false"`

### 6단계: 사용처 연결 (선택)

사용자가 요청하면 Compose / XML 사용처에 `stringResource(R.string.xxx)` 치환까지 진행.

```kotlin
// Before
Text("영수증 다운로드")

// After
Text(stringResource(R.string.payment_bill_download_action))
```

**주의**: 타 feature 의 R.string 을 import 하지 않는다. 공유가 필요하면 `core:common` 으로 승격.

### 7단계: 결과 보고

- 추가된 key 목록 + 파일 경로
- 사용처 치환 여부
- 중복/승격 필요 감지 사항

## 핵심 규칙

### 필수
- snake_case
- `{feature}_{screen}_{purpose}` 계층
- 기존 공통 문자열 (`core:common`) 재사용
- 존댓말 (토스트/에러/안내 모두)
- 포맷 플레이스홀더 정확히 (`%s`, `%d`, `%,d`, `%1$s`)

### 금지
- 하드코딩된 문자열
- 중복 key 추가
- 타 feature strings.xml 에 삽입
- camelCase / PascalCase key
- 컨벤션 문서에 없는 prefix 를 임의로 만들기 (새 prefix 가 필요하면 컨벤션 문서를 먼저 업데이트)

## 참고 문서

- [String 리소스 컨벤션](../../.docs/conventions/string-resource-convention.md)
- [UI 컨벤션](../../.docs/conventions/ui-convention.md)

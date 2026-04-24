---
name: crm-ios-crashlytics-analyze
description: Firebase Crashlytics 크래시 리포트를 조회하고 분석합니다. topIssues 조회, 시스템/앱 크래시 자동 분류, 특정 이슈 상세 분석을 수행합니다.
allowed-tools: mcp__firebase__crashlytics_get_report, mcp__firebase__crashlytics_get_issue, mcp__firebase__crashlytics_list_events, mcp__firebase__crashlytics_batch_get_events, mcp__firebase__crashlytics_list_notes, Read
---

# Crashlytics Analyze

Firebase Crashlytics 크래시 리포트를 조회하고 분석하는 스킬입니다.

## 실행 알림
이 스킬이 실행되면 가장 먼저 "[crm-ios-crashlytics-analyze] 스킬이 실행되었습니다."를 출력할 것

## 실행 시점

- "크래시 분석", "crm-ios-crashlytics-analyze", "크래시리틱스 분석", "크래시 리포트" 키워드 감지 시

## 상수

- **Firebase App ID**: `1:704568586288:ios:afd9718918718c09b37df5`

## 실행 모드

### 모드 판별
- **인자 없음** → 리포트 모드 (topIssues 목록 조회)
- **이슈 ID 있음** → 상세 모드 (특정 이슈 심층 분석)

---

## 리포트 모드 (topIssues 조회)

### 1단계: topIssues 조회

```
mcp__firebase__crashlytics_get_report 사용
- appId: "1:704568586288:ios:afd9718918718c09b37df5"
- report: "topIssues" (기본값)
- pageSize: 20 (기본값)
- filter:
  - intervalStartTime: 30일 전 (ISO 8601 형식)
  - intervalEndTime: 현재 (ISO 8601 형식)
```

사용자가 기간/타입/건수를 지정한 경우 해당 파라미터로 오버라이드

### 2단계: 이벤트 상세 조회

topIssues의 각 이슈에서 sampleEvent ID를 추출하여 batch_get_events 호출:

```
mcp__firebase__crashlytics_batch_get_events 사용
- appId: "1:704568586288:ios:afd9718918718c09b37df5"
- issueId: "{이슈ID}"
- eventIds: ["{sampleEvent ID}"]
```

가능하면 여러 이슈를 병렬로 조회하여 성능 최적화

### 3단계: 크래시 자동 분류

각 이슈의 스택 트레이스를 분석하여 분류:

| 분류 | 조건 | 라벨 |
|------|------|------|
| **IGNORE** | SIGTERM + 시스템 프레임워크만 (CoreFoundation, RunningBoardServices, UIKitCore, libsystem, libdispatch 등) | 시스템 크래시 (조치 불필요) |
| **ACTION** | EXC_BREAKPOINT / EXC_BAD_ACCESS / SIGABRT + 앱 코드 경로 포함 | 앱 크래시 (수정 필요) |
| **REVIEW** | SIGTERM + 앱 코드 경로 포함 | 메모리/백그라운드 이슈 가능성 |

**앱 코드 판별 키워드:**
- `gongbiz_crm_b2b`
- `gongbiz-crm-b2b`
- `Common`
- `NetworkSystem`

### 4단계: 결과 출력

ACTION → REVIEW → IGNORE 순서로 정렬하여 테이블 형태로 출력:

```markdown
## Crashlytics 리포트

### ACTION (수정 필요) - N건
| # | 이슈 ID | 제목 | 시그널 | 발생 수 | 영향 사용자 | 주요 프레임 |
|---|---------|------|--------|---------|-------------|-------------|
| 1 | {ID}    | ...  | ...    | ...     | ...         | ...         |

### REVIEW (검토 필요) - N건
| # | 이슈 ID | 제목 | 시그널 | 발생 수 | 영향 사용자 | 주요 프레임 |
|---|---------|------|--------|---------|-------------|-------------|

### IGNORE (조치 불필요) - N건
| # | 이슈 ID | 제목 | 시그널 | 발생 수 | 영향 사용자 | 비고 |
|---|---------|------|--------|---------|-------------|------|
```

### 5단계: 다음 단계 안내

```
특정 이슈를 상세 분석하려면:
  /crm-ios-crashlytics-analyze {이슈ID}

크래시 수정 작업을 시작하려면:
  /crm-ios-crashlytics-fix {이슈ID}
```

---

## 상세 모드 (특정 이슈 분석)

### 1단계: 이슈 상세 조회

```
mcp__firebase__crashlytics_get_issue 사용
- appId: "1:704568586288:ios:afd9718918718c09b37df5"
- issueId: "{이슈ID}"
```

### 2단계: 추가 정보 병렬 조회

다음 정보를 가능한 한 병렬로 조회:

1. **이벤트 목록**: `list_events`로 최근 이벤트 조회
2. **노트 확인**: `list_notes`로 기존 작업 노트 확인

get_issue 응답에 포함된 정보 활용:
- topVersions (영향받는 앱 버전)
- topOperatingSystems (OS 버전)
- topAppleDevices (기기 정보)

### 3단계: 스택 트레이스 분석

이벤트 상세에서 스택 트레이스를 추출하고:
1. 앱 코드 경로만 필터링 (gongbiz_crm_b2b, Common, NetworkSystem)
2. 크래시 발생 지점 식별
3. 관련 파일/함수 목록 정리

### 4단계: 상세 분석 결과 출력

```markdown
## 크래시 상세 분석

### 기본 정보
- **이슈 ID**: {issueId}
- **제목**: {title}
- **시그널**: {signal} / {exception type}
- **분류**: {ACTION/REVIEW/IGNORE}
- **총 발생 수**: {count}
- **영향 사용자 수**: {users}

### 영향 범위
- **앱 버전**: {versions}
- **OS 버전**: {os versions}
- **주요 기기**: {devices}

### 스택 트레이스 (앱 코드)
{앱 코드 관련 프레임만 발췌}

### 관련 코드 파일
- {파일경로1} (함수명)
- {파일경로2} (함수명)

### 기존 노트
{노트 내용 또는 "없음"}

### 분석 의견
{크래시 원인 추정 및 수정 방향 제안}

### 다음 단계
수정 작업을 시작하려면: `/crm-ios-crashlytics-fix {이슈ID}`
```

---

## 주의사항

- 이 스킬은 **읽기 전용**입니다 (노트 추가, 이슈 업데이트 등 쓰기 작업 불가)
- 스택 트레이스 분석 시 앱 코드 프레임을 우선적으로 확인
- 시스템 프레임워크만 포함된 크래시는 IGNORE로 분류하되, 앱 코드가 조금이라도 포함되면 REVIEW 이상으로 분류

## 참조 문서

- 호칭: `CLAUDE.local.md`

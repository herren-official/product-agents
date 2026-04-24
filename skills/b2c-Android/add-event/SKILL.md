---
name: b2c-android-add-event
description: "마케팅 이벤트를 B2CEventType enum에 추가하고 해당 화면에 심는 작업을 자동화. Use when: 이벤트 추가, 이벤트 심기, 마케팅 이벤트, AppsFlyer 이벤트 관련 작업"
argument-hint: "<이벤트설명 또는 상태> (예: '전시 상세 공유', 'all', '신규', '수정')"
allowed-tools: ["bash", "read", "write", "edit", "grep", "glob"]
---

# 마케팅 이벤트 추가

마케팅팀이 구글 시트에 정의한 이벤트 스펙(CSV)을 기반으로, B2CEventType enum 등록 → 코드에 심기 → 이벤트 맵 문서 업데이트까지 자동으로 수행합니다.

요청: $ARGUMENTS

## 필수 참조
- **이벤트 스펙 CSV**: `.docs/event/` 디렉토리 내 CSV 파일 (구글 시트 "B2C-Firebase&AF" 탭 다운로드)
- **이벤트 맵**: `.docs/event-map.md` (전체 이벤트 현황, 기존 패턴 확인)
- **이벤트 상수**: `core/common/src/main/java/com/herren/gongb2c/common/utils/AppsFlyerLogEventUtil.kt`

## CSV 컬럼 매핑

구글 시트 "B2C-Firebase&AF" 탭의 CSV 구조:

| CSV 컬럼 | 의미 | 활용 |
|----------|------|------|
| `page` | 화면/페이지명 | 코드에서 심을 Screen 특정 |
| (2번째 컬럼, 이름 없음) | 세부 액션 | 트리거 유형 파악 (진입, 클릭, 완료 등) |
| `Android 적용 플랫폼` | 전송 대상 플랫폼 | 어떤 Util을 호출할지 결정 |
| `Event Name` | 이벤트 이름 | B2CEventType enum의 eventName 값 |
| `목적` | 이벤트 목적 | enum 주석으로 활용 |
| `Trigger Description` | 트리거 조건 상세 | 코드에서 이벤트를 심을 정확한 위치/시점 |
| `Parameter` | 추가 파라미터 | B2CEventParam 매핑 |
| `상태` | 적용 상태 | **신규/수정 = 작업 대상**, 완료 = 이미 적용됨 |
| `요청 파트` | 요청한 파트 | 참고용 |

## 작업 순서

### Step 0: CSV 읽기 및 대상 이벤트 필터링
1. `.docs/event/` 디렉토리에서 CSV 파일을 찾아 읽기 (파일명은 다를 수 있음)
2. **상태 컬럼 기준으로 필터링**:
   - `신규`: 아직 코드에 적용되지 않은 새 이벤트 → **추가 대상**
   - `수정`: 기존 이벤트 스펙이 변경됨 → **수정 대상**
   - `완료`: 이미 적용 완료 → 스킵
3. `$ARGUMENTS`에 따른 처리:
   - `all` → 상태가 `신규` 또는 `수정`인 모든 이벤트 처리
   - `신규` → 상태가 `신규`인 이벤트만
   - `수정` → 상태가 `수정`인 이벤트만
   - 이벤트 설명 (예: '전시 상세 공유') → CSV에서 page/액션/eventName이 매칭되는 행을 찾아 사용

### Step 1: 대상 이벤트 확인
1. `AppsFlyerLogEventUtil.kt`를 읽어 기존 `B2CEventType` enum과 `B2CEventParam` 목록 파악
2. `.docs/event-map.md`에서 이미 적용된 이벤트 확인 (중복 방지)
3. 사용자에게 CSV에서 읽은 대상 이벤트를 표로 보여주고 확인받기:

```
| 상태 | page | 액션 | Event Name | Android 플랫폼 | 파라미터 |
|------|------|------|------------|---------------|----------|
| 신규 | 전시 상세 | 진입 | curation_enter | Appsflyer, Firebase | curationName |
```

4. 각 이벤트에 대해 결정:
   - **enum 이름**: eventName → `EVT_` 접두사 + UPPER_SNAKE_CASE로 변환
   - **eventName**: CSV의 `Event Name` 값 그대로 사용
   - **플랫폼**: CSV의 `Android 적용 플랫폼` 값으로 Util 결정
   - **파라미터**: CSV의 `Parameter` 값 → 기존 `B2CEventParam` 매핑
   - **심을 위치**: `page` + `Trigger Description`으로 Screen/ViewModel 코드 위치 특정

### Step 2: B2CEventType enum에 추가
- enum 이름: `EVT_` 접두사 + UPPER_SNAKE_CASE
- eventName: CSV의 `Event Name` 값 그대로
- 주석: `//` 한글 설명 (page + 액션)
- 관련 이벤트끼리 근처에 배치

### Step 3: 필요 시 B2CEventParam에 파라미터 추가
- CSV `Parameter` 컬럼에 정의된 파라미터 중 기존에 없는 것만 새로 추가
- 기존 파라미터 재사용 가능하면 새로 만들지 않음

### Step 4: 코드에 이벤트 심기
- CSV의 `Trigger Description`을 기반으로 심을 위치 결정
- 기존 코드에서 유사 이벤트 호출 패턴을 찾아 동일한 방식으로 심기
- 심는 위치 기준:
  | 트리거 유형 | 위치 |
  |------------|------|
  | 진입 (-뒤로가기 시 제외) | Screen의 `LaunchedEffect` |
  | 버튼 클릭 | Screen의 onClick 또는 SideEffect 핸들러 |
  | 예약 완료 | ReceiptScreen 또는 성공 SideEffect 핸들러 |
- `Android 적용 플랫폼`에 따라 호출할 Util 결정:
  | 플랫폼 | 호출 코드 |
  |--------|----------|
  | `Appsflyer, Firebase` | `AppsFlyerLogEventUtil.sendLogEvent()` |
  | `Firebase` | `FirebaseLogEventUtil.sendLogEvent()` |
  | `Appsflyer, Firebase, Amplitude` | `AppsFlyerLogEventUtil` + `AmplitudeLogEventUtil` |

### Step 5: 이벤트 맵 문서 업데이트
`.docs/event-map.md`에 해당 카테고리 테이블에 행 추가

### Step 6: 결과 요약
```
## 이벤트 추가 완료

### 추가된 이벤트
| 상태 | 이벤트 | Event Name | 플랫폼 | 트리거 | 파라미터 |
|------|--------|------------|--------|--------|----------|
| 신규 | EVT_CURATION_ENTER | curation_enter | AF+FB | 전시 상세 진입 | curationName |

### 변경된 파일
1. `AppsFlyerLogEventUtil.kt` — enum 추가/수정
2. `{Screen}.kt:{라인}` — 이벤트 심기
3. `.docs/event-map.md` — 문서 업데이트
```

## CSV 파일이 없는 경우
`.docs/event/` 디렉토리에 CSV 파일이 없으면 사용자에게 안내:
> 이벤트 스펙 CSV가 없습니다. 구글 시트 "B2C-Firebase&AF" 탭을 CSV로 다운로드하여 `.docs/event/` 폴더에 저장해주세요.

## 사용 예시
```bash
/add-event all             # 신규 + 수정 이벤트 전체
/add-event 신규             # 신규 이벤트만
/add-event 수정             # 수정된 이벤트만
/add-event 전시 상세 공유    # 특정 이벤트 검색
```

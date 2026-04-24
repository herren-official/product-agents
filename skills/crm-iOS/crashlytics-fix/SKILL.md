---
name: crm-ios-crashlytics-fix
description: Crashlytics 이슈 기반으로 노션 일감 생성, Git 브랜치 생성, Crashlytics 노트 추가, 코드 분석 및 사이드이펙트 검증까지 수행하는 수정 워크플로우 스킬입니다.
allowed-tools: Bash, Read, Glob, Grep, mcp__firebase__crashlytics_get_issue, mcp__firebase__crashlytics_create_note, mcp__firebase__crashlytics_list_notes, mcp__firebase__crashlytics_update_issue, mcp__notionMCP__notion-fetch, mcp__notionMCP__notion-create-pages, mcp__notionMCP__notion-update-page, mcp__claude_ai_Notion__notion-fetch, mcp__claude_ai_Notion__notion-create-pages, mcp__claude_ai_Notion__notion-update-page
---

# Crashlytics Fix

Crashlytics 이슈 기반으로 수정 워크플로우를 자동화하는 스킬입니다.

## 워크플로우 개요

**Phase 1 (빠른 셋업)**: 이슈 조회 → 기본 노션 문서 생성 → 브랜치 생성 → Crashlytics 노트
**Phase 2 (코드 분석)**: 관련 코드 파악 → 시나리오 분석 → 수정 방향 도출 → 사이드이펙트 검증 → 노션 문서 보충 → 보고

## 실행 알림
이 스킬이 실행되면 가장 먼저 "[crm-ios-crashlytics-fix] 스킬이 실행되었습니다."를 출력할 것

## 실행 시점

- "크래시 수정", "crm-ios-crashlytics-fix", "크래시 픽스" 키워드 감지 시
- `/crm-ios-crashlytics-analyze` 스킬에서 안내받아 실행 시

## 상수

- **Firebase App ID**: `1:704568586288:ios:afd9718918718c09b37df5`

---

## Phase 1: 빠른 셋업

### 1단계: 이슈 ID 확인

인자로 받은 이슈 ID 또는 대화 컨텍스트에서 이슈 ID 확인.
이슈 ID가 없으면 사용자에게 요청:

```
"[호칭], 수정할 Crashlytics 이슈 ID를 알려주세요.
/crm-ios-crashlytics-analyze 로 이슈 목록을 먼저 확인할 수 있습니다."
```

### 2단계: 이슈 상세 조회 및 중복 확인

병렬로 실행:

```
1. mcp__firebase__crashlytics_get_issue
   - appId: "1:704568586288:ios:afd9718918718c09b37df5"
   - issueId: "{이슈ID}"

2. mcp__firebase__crashlytics_list_notes
   - appId: "1:704568586288:ios:afd9718918718c09b37df5"
   - issueId: "{이슈ID}"
```

기존 노트에 "작업 시작" 또는 "GBIZ-" 가 포함되어 있으면:
```
"[호칭], 이 이슈에 이미 작업 시작 노트가 있습니다:
  {노트 내용}
계속 진행하시겠습니까?"
```

### 3단계: 작업 계획 확인

이슈 정보를 바탕으로 일감 제목, 브랜치명 미리보기 후 사용자 확인:

```
"[호칭], 다음과 같이 작업을 진행하겠습니다.

1. 노션 일감 생성 (기본 정보)
   - 제목: [CRM][iOS] Crashlytics 크래시 수정 - {이슈 제목 요약}
   - 유형: 버그

2. Git 브랜치 생성
   - 브랜치명: GBIZ-{번호}-Fix-Crash-{간략설명}
   (GBIZ 번호는 노션 일감 생성 후 자동 추출)

3. Crashlytics 노트 추가
   - '작업 시작 - GBIZ-{번호} / 브랜치: {브랜치명}'

4. 코드 분석 및 노션 문서 보충
   - 크래시 시나리오, 문제 코드 분석, 수정 방향, 사이드이펙트 검증

진행할까요? [Y] 진행 / [N] 취소 / [E] 수정"
```

### 4단계: 작업자 정보 확인

`CLAUDE.local.md` 파일에서 작업자 정보 확인.

### 5단계: 노션 일감 생성 (기본 정보)

**반드시 `.docs/NOTION_TASK_GUIDE.md`를 참조하여 생성할 것.**

크래시 일감 특화 속성:
- **아이콘**: `🐞` (버그 아이콘)
- **이름**: `[CRM][iOS] Crashlytics 크래시 수정 - {이슈 제목 요약}`
- **유형**: `버그` (크래시이므로 "작업"이 아닌 "버그")
- **서비스**: `["공비서-B2B"]`
- **나머지 속성**: NOTION_TASK_GUIDE.md의 필수 속성 규칙 따름

**Phase 1 content 템플릿** (Crashlytics 정보만으로 작성):

```markdown
## **작업내용** {color="blue_bg"}
### 내용
<callout icon="💡" color="gray_bg">
	작업 상세 내용으로 해야할 작업을 세분화하여 정리하여 작성한다
</callout>

Firebase Crashlytics에서 감지된 크래시를 수정합니다.

**크래시 정보**
- 이슈 ID: {issueId}
- 시그널: {signal} / {exception type}
- 발생 수: {count}
- 영향 사용자: {users}
- 영향 버전: {versions}

**스택 트레이스 (앱 코드)**
{앱 코드 관련 프레임 발췌}

**관련 코드 파일**
- {파일경로1}
- {파일경로2}

### 참고
<callout icon="💡" color="gray_bg">
	설계/문서/피그마/슬랙 링크 등
</callout>

- Firebase Crashlytics 이슈: {issueId}

---
## TT {color="orange_bg"}
### Todo
- [ ] 크래시 원인 분석
- [ ] 코드 수정
- [ ] 빌드 확인
- [ ] Crashlytics에서 크래시 재발 모니터링

### Test Case
공비서팀 Test Case DB 보기
```

### 6단계: GBIZ 번호 추출

생성된 페이지 ID로 fetch하여 GBIZ 번호 확인:

```
mcp__notionMCP__notion-fetch 또는 mcp__claude_ai_Notion__notion-fetch 사용
- id: "{생성된 페이지 URL 또는 ID}"
```

응답의 properties에서 `userDefined:ID` 필드에서 GBIZ 번호 추출.

**주의**: GBIZ 번호가 즉시 생성되지 않는 경우가 있음. 이 경우:
1. 몇 초 대기 후 재조회
2. 그래도 없으면 사용자에게 노션에서 직접 확인 요청

### 7단계: Git 브랜치 생성

```bash
# 현재 브랜치 확인
git branch --show-current

# develop 기준으로 브랜치 생성
git checkout develop
git pull origin develop
git checkout -b GBIZ-{번호}-Fix-Crash-{간략설명}
```

**간략설명 규칙:**
- 영문 사용
- 단어는 하이픈(-) 으로 연결
- 크래시 원인을 간결하게 표현
- 예: `Fix-Crash-NilPointer-PaymentView`, `Fix-Crash-IndexOutOfRange-SaleList`

### 8단계: Crashlytics 노트 추가

```
mcp__firebase__crashlytics_create_note 사용
- appId: "1:704568586288:ios:afd9718918718c09b37df5"
- issueId: "{이슈ID}"
- body: "작업 시작 - GBIZ-{번호} / 브랜치: {브랜치명}"
```

### Phase 1 완료 중간 보고

```
"[호칭], Phase 1 완료했습니다.
- 노션 일감: GBIZ-{번호}
- 브랜치: {브랜치명}
- Crashlytics 노트 추가 완료

이어서 코드 분석을 진행합니다."
```

---

## Phase 2: 코드 분석 및 문서 보충

### 9단계: 관련 코드 파악

대화 컨텍스트에 `/crm-ios-crashlytics-analyze` 등으로 이미 분석된 내용이 있으면 활용하고, 없으면 새로 탐색.

스택 트레이스에서 앱 코드 프레임을 추출하여 관련 파일을 탐색:

1. **크래시 발생 함수** 찾기: Glob/Grep으로 스택 트레이스의 클래스명, 함수명 검색
2. **크래시 발생 함수** 읽기: Read로 해당 함수의 전체 코드 확인
3. **호출 체인** 추적: 크래시 함수를 호출하는 상위 함수들 읽기
4. **데이터 흐름** 파악: 크래시에 관련된 프로퍼티가 어디서 설정/변경되는지 확인

**주의**: 파일을 찾을 수 없는 경우 사용자에게 파일 경로 확인 요청

### 10단계: 크래시 발생 시나리오 분석

코드를 기반으로 크래시가 발생하는 **구체적 시나리오**를 도출:

1. **어떤 사용자 행동**이 크래시를 유발하는지
2. **어떤 코드 경로**를 거쳐 크래시에 도달하는지
3. **발생 확률** 평가 (높음/보통/낮음/극히 낮음)

**주의**: 시나리오는 반드시 코드 근거가 있어야 함. 추측이 아닌 코드 흐름 기반 분석.

### 11단계: 수정 방향 도출

각 수정 사항에 대해:
1. **현재 코드**: 문제가 되는 코드 (line 번호 포함)
2. **수정 코드**: 어떻게 변경할 것인지
3. **수정 근거**: 왜 이 수정이 크래시를 방지하는지

### 12단계: 사이드이펙트 검증

**⚠️ 이 단계는 반드시 수행해야 합니다.**

각 수정 사항에 대해 사이드이펙트 발생 여부를 검증하고, Q&A 형식으로 정리:

#### 검증 체크리스트

1. **스레드 안전성**: 수정된 코드가 동기/비동기 컨텍스트에서 안전한가?
   - 해당 함수가 어떤 스레드에서 호출되는지 확인
   - 데이터 변경이 같은 스레드에서 일어나는지 확인
   - 로컬 변수 캡처로 일관된 스냅샷을 사용하는지 확인

2. **반환값 변경 영향**: 반환 타입이나 값 변경이 호출부에 영향을 주는가?
   - 기존 반환 타입과 호환되는지 확인
   - nil/0/빈 값 반환 시 호출부가 이를 처리할 수 있는지 확인

3. **기존 동작 보존**: 정상 경로(index 유효)에서 기존과 100% 동일하게 동작하는가?
   - guard 통과 후 로직이 기존과 동일한지 확인

4. **UI 영향**: 방어 처리로 인해 사용자에게 보이는 비정상 UI가 발생하는가?
   - 빈 값 반환 후 후속 처리(reloadData 등)가 정상 복구하는지 확인

#### Q&A 형식 정리

각 검증 항목을 다음 형식으로 작성:

```
**Q: {사이드이펙트 우려 질문}**

{발생하지 않는 이유를 코드 근거와 함께 설명}
```

### 13단계: 노션 문서 보충

Phase 1에서 생성한 노션 문서에 다음 섹션을 추가 (replace_content 사용):

**Phase 2 보충 content 템플릿**:

```markdown
## **작업내용** {color="blue_bg"}
### 내용
<callout icon="💡" color="gray_bg">
	작업 상세 내용으로 해야할 작업을 세분화하여 정리하여 작성한다
</callout>

Firebase Crashlytics에서 감지된 크래시를 수정합니다.

**크래시 정보**
- 이슈 ID: {issueId}
- 시그널: {signal} / {exception type}
- 발생 수: {count}
- 영향 사용자: {users}
- 영향 버전: {versions}

**스택 트레이스 (앱 코드)**
{앱 코드 관련 프레임 발췌}

**관련 코드 파일**
- {파일경로1}
- {파일경로2}

---

### 크래시 발생 시나리오

**시나리오: {시나리오 제목}**

1. {단계 1}
2. {단계 2}
3. ...
{n}. {크래시 발생 단계}

**발생 확률**: {높음/보통/낮음/극히 낮음} ({이유})

---

### 문제 코드 분석

**문제 코드 1: {설명} (line {N})**
```swift
{문제 코드 스니펫}
```
- {왜 문제인지 설명}

**문제 코드 2: {설명} (line {N})**
```swift
{문제 코드 스니펫}
```
- {왜 문제인지 설명}

{필요한 만큼 반복}

---

### 수정 방향

**수정 1: {함수명/위치} - {수정 내용 요약}**
- {현재 코드 설명} → {수정 코드 설명}
- {수정 근거}

**수정 2: {함수명/위치} - {수정 내용 요약}**
- {현재 코드 설명} → {수정 코드 설명}
- {수정 근거}

---

### 사이드이펙트 검증

**Q1. {사이드이펙트 우려 질문}**

{발생하지 않는 이유}:
- {코드 근거 1}
- {코드 근거 2}

**Q2. {사이드이펙트 우려 질문}**

{발생하지 않는 이유}:
- {코드 근거 1}
- {코드 근거 2}

**결론: {한 줄 요약}**

### 참고
<callout icon="💡" color="gray_bg">
	설계/문서/피그마/슬랙 링크 등
</callout>

- Firebase Crashlytics 이슈: {issueId}

---
## TT {color="orange_bg"}
### Todo
- [ ] {구체적 수정 항목 1}
- [ ] {구체적 수정 항목 2}
- [ ] 빌드 확인
- [ ] Crashlytics에서 크래시 재발 모니터링

### Test Case
공비서팀 Test Case DB 보기
```

**주의**: Todo 항목은 "크래시 원인 분석"처럼 일반적인 표현이 아닌, "getCosmeticVO에 bounds check 추가"처럼 **구체적인 수정 항목**으로 작성

### 14단계: 분석 완료 보고

```markdown
## 크래시 수정 워크플로우 완료

### 생성된 리소스
- **노션 일감**: [CRM][iOS] Crashlytics 크래시 수정 - {요약}
  - GBIZ 번호: GBIZ-{번호}
  - URL: {노션 페이지 URL}
- **Git 브랜치**: GBIZ-{번호}-Fix-Crash-{간략설명}
- **Crashlytics 노트**: 작업 시작 노트 추가 완료

### 분석 결과 요약
- **크래시 원인**: {한 줄 요약}
- **발생 시나리오**: {한 줄 요약}
- **수정 방향**: {수정 항목 나열}
- **사이드이펙트**: 없음 ({한 줄 근거})

### 다음 단계
1. 코드 수정을 진행하세요
2. 수정 완료 후: `/crm-ios-commit` 으로 커밋
3. PR 생성: `/crm-ios-pr` 으로 Pull Request 생성
```

---

## 에러 처리

### 노션 일감 생성 실패 시
1. 에러 메시지 확인
2. `.docs/NOTION_TASK_GUIDE.md`의 트러블슈팅 섹션 참조
3. DB 접근 권한 문제인 경우 사용자에게 안내

### GBIZ 번호 추출 실패 시
1. 페이지 재조회 (최대 2회)
2. 실패 시 사용자에게 노션에서 직접 GBIZ 번호 확인 요청
3. 사용자가 제공한 번호로 계속 진행

### 브랜치 생성 실패 시
1. 이미 존재하는 브랜치인 경우 사용자에게 확인
2. develop pull 실패 시 현재 브랜치에서 생성 여부 확인

## 금지 사항

- 사용자 확인 없이 노션 일감 생성하지 않음
- 사용자 확인 없이 브랜치를 생성하지 않음
- GBIZ 번호를 추측하지 않음 (반드시 노션에서 확인)
- `git push` 하지 않음 (커밋/PR은 별도 스킬에서 처리)
- 사이드이펙트 검증을 건너뛰지 않음 (Phase 2 필수)
- 코드 근거 없이 시나리오를 추측하지 않음

## 참조 문서

- 노션 일감 가이드: `.docs/NOTION_TASK_GUIDE.md`
- Git 가이드: `.docs/GIT_GUIDE.md`
- 호칭: `CLAUDE.local.md`

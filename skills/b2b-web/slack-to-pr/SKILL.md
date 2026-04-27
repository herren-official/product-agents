---
name: b2b-web-slack-to-pr
description: "슬랙 스레드 → 노션 백로그 생성 → 코드 수정 → PR 생성 전체 자동화"
argument-hint: "<slack-thread-url>"
---

# Slack → Notion → PR 워크플로우

슬랙 스레드 링크를 받아 노션 백로그 생성 → 코드 수정 → PR 생성까지 전체 워크플로우를 자동화합니다.

## 입력

`$ARGUMENTS` — 슬랙 스레드 URL (필수)

예: `https://herrencorp.slack.com/archives/C07USBX8Q5S/p1775129162031429`

## 처리 단계

### 1️⃣ 슬랙 스레드 읽기

슬랙 URL에서 channel_id와 message_ts를 추출합니다.
- URL 패턴: `https://herrencorp.slack.com/archives/{channel_id}/p{timestamp}`
- timestamp 변환: `p1775129162031429` → `1775129162.031429`

`slack_read_thread` MCP 도구로 스레드 내용을 읽고 다음을 파악합니다:
- **작업 내용**: 무엇을 변경해야 하는지
- **요청자**: 누가 요청했는지
- **긴급도**: 일정 언급이 있는지
- **참고 링크**: Figma, 노션 등 관련 URL
- **웹/앱 구분**: 마티(웹) 관련 멘션 확인

파악한 내용을 사용자에게 요약하여 보여주고 확인을 받습니다:

```
📋 슬랙 스레드 분석 결과:
- 작업: {작업 내용 요약}
- 요청자: {이름}
- 플랫폼: 웹(Frontend)

이 내용이 맞나요?
```

### 2️⃣ 노션 백로그 생성

**데이터베이스**: 공비서팀 제품 백로그(NEW) DB
- data_source_id: `afbb2565-672a-44cd-85f4-45ba566e3613`

`notion-create-pages` MCP 도구로 백로그 항목을 생성합니다:

| 속성 | 값 | 비고 |
|---|---|---|
| 이름 | [웹] {작업 내용 요약} | 제목에 [웹] 접두어 |
| 유형 | 작업 | |
| 플랫폼 | ["Frontend"] | JSON 배열 |
| 서비스 | ["공비서-B2B"] | JSON 배열 |
| 상태 | 작업 중 | |
| 우선순위 | 슬랙 문맥에서 판단 | 상/중/하 |
| 스토리포인트 | 변경 규모에 따라 판단 | 단순 문구: 1, 로직 변경: 2~3 |

**페이지 본문 내용**:
```markdown
## 작업 내용

{기존 → 변경 내용 상세}

## 슬랙 스레드

{슬랙 URL}

## 수정 파일

- {파일 경로와 라인 번호}
```

생성 후 `notion-fetch`로 GBIZ ID(userDefined:ID)를 확인합니다.

### 3️⃣ 코드 수정 대상 파악 및 변경

슬랙 스레드에서 파악한 변경 내용을 기반으로:

1. **코드 검색**: Grep/Glob으로 변경 대상 파일 찾기
2. **변경 내용 확인**: 사용자에게 변경 전/후를 보여주고 확인
3. **코드 수정**: Edit 도구로 변경 적용
4. **테스트 확인**: 변경된 상수/문자열을 참조하는 테스트가 있는지 Grep으로 확인

### 4️⃣ 브랜치/커밋/PR 생성

#### 브랜치 생성
```bash
git checkout develop
git pull origin develop
git checkout -b GBIZ-{ID}-{영문-기능-설명}
```

브랜치명 규칙:
- GBIZ-ID는 대문자 유지
- 한글 작업 내용을 영어로 번역하여 소문자+하이픈

#### 커밋
[커밋 컨벤션](/.docs/conventions/COMMIT_CONVENTION.md)을 따릅니다:
```
fix(GBIZ-{ID}): {한글 설명}
```

- 본문 없이 제목만 작성
- worktree 간섭으로 pre-commit hook 실패 시 `HUSKY=0` 사용

#### PR 생성
`gh pr create`로 PR을 생성합니다:
- base: develop
- assignee: marty404

PR 본문 템플릿 (5섹션 필수):

```markdown
## 🎯 작업 내용

{변경 내용 상세 - 기존/변경 비교}

## 📋 체크리스트

- [x] 문구/코드 변경 확인
- [x] 빌드 오류 없음 확인
- [ ] QA 확인

## 🧪 테스트

{영향받는 테스트 유무, 수동 확인 필요 사항}

## 📸 스크린샷

{UI 변경이 있으면 캡쳐, 없으면 "단순 문구 수정으로 생략"}

## 💭 리뷰 요청사항

{슬랙 스레드 링크, 노션 백로그 링크}
```

### 5️⃣ 노션 백로그 업데이트

PR URL을 노션 백로그의 `GitHub 풀 리퀘스트` 속성에 추가합니다.

### 6️⃣ 최종 보고

```
✅ 전체 워크플로우 완료!

| 단계 | 결과 |
|---|---|
| 슬랙 확인 | {작업 내용 요약} |
| 노션 백로그 | GBIZ-{ID} ({노션 URL}) |
| 코드 수정 | {변경 파일 목록} |
| PR | #{PR번호} ({PR URL}) |
```

## Figma 링크가 있는 경우

슬랙 스레드에 Figma URL이 포함되어 있으면:
1. `get_screenshot` 또는 `get_design_context`로 디자인 확인
2. 디자인과 코드 변경 내용 대조
3. rate limit 발생 시 `figma-dev-mode-mcp-server` 사용

## 주의사항

- 슬랙 스레드 내용이 모호하면 반드시 사용자에게 확인
- 코드 변경 전 변경 전/후를 사용자에게 보여주고 승인 받기
- PR 본문은 반드시 5섹션 형식 준수 (메모리: PR 본문 5섹션 필수)
- worktree hook 실패 시 HUSKY=0 사용 (메모리: worktree hook 실패 무시)

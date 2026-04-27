---
name: b2b-web-resolve-issue
description: "이슈 해결 워크플로우: 백로그 생성 > 브랜치/워크트리 > 작업 > PR (end-to-end)"
argument-hint: "[Slack 스레드 링크 또는 이슈 제목]"
allowed-tools: ["bash", "read", "write", "edit", "multi_edit", "grep", "glob", "ls", "slack_read_thread", "notion-search", "notion-fetch", "notion-update-page", "get_design_context"]
---

# 이슈 해결 워크플로우

## 개요
CRM 이슈/버그 해결을 위한 end-to-end 워크플로우.
기능 개발용 스킬(generate-backlog-branch, create-pr)과는 별도로 운영.

**각 Step 완료 후 사용자에게 결과를 보고하고 다음 단계 진행 여부를 확인받는다.**

---

## Step 0: Slack 스레드 자동 파싱 (선택)

### Slack 링크가 제공된 경우
사용자가 Slack 스레드 URL을 입력하면 자동으로 컨텍스트를 추출한다.

#### URL 파싱
Slack 스레드 URL 형식: `https://{workspace}.slack.com/archives/{channelId}/p{timestamp}`
- `channelId`: 채널 ID (예: `C023VAWS002`)
- `timestamp`: 메시지 타임스탬프. `p` 제거 후 10자리.6자리로 변환 (예: `p1775792192190599` → `1775792192.190599`)

#### Slack MCP로 스레드 읽기
```
slack_read_thread(channel_id, message_ts)
```

#### 자동 추출 항목
스레드 내용에서 다음을 자동으로 판단:
1. **이슈 요약**: 스레드 첫 메시지에서 문제/요청 사항 추출
2. **이슈 제목**: `[CRM][Front][Claude] {요약}` 형식으로 자동 생성
3. **에픽명**: 채널/서브팀 태그 기반 자동 판단 (아래 규칙)
4. **유형**: 버그 보고면 `버그`, 기능 요청이면 `작업`
5. **일정**: 스레드에 배포일/QA일이 언급되면 추출
6. **Figma 링크**: 스레드에 공유된 Figma URL 추출
7. **관련 담당자**: 멘션된 사용자 목록

#### 에픽 자동 판단 규칙
1. 스레드에 `@스위퍼` 서브팀 태그 → `26-Q2-스위퍼`
2. 채널명에 특정 키워드 포함 시 매핑 (확장 가능)
3. 판단 불가 시 → 사용자에게 에픽명 질문
4. `notion-search`로 에픽 URL 검색

#### 추출 결과 보고
파싱한 내용을 사용자에게 요약 보고하고, 누락/수정 사항을 확인받은 후 Step 1로 진행.

### Slack 링크가 없는 경우
기존 방식대로 사용자에게 직접 질문하여 정보 수집.

---

## Step 1: Notion 백로그 생성

### 사전 확인 (사용자에게 질문)
Step 0에서 자동 추출되지 않은 항목만 질문:
- 이슈 제목 (예: `[CRM][Front][Claude] 설명`)
- 에픽명 (Step 0에서 자동 판단되었으면 스킵)
- 스토리포인트 (사용자가 "너가 판단"이면 작업 규모 기반 0.2~3 범위에서 결정)
- 마일스톤 (기본: 없음)
- 유형 (기본: 버그, 사용자가 다른 유형 지정 가능)

### 백로그 DB 정보
- Data source: `collection://afbb2565-672a-44cd-85f4-45ba566e3613`
- 버그 유형 템플릿 ID: `8a4e0981-66a4-4ba3-baf2-af9111a1cc89`
- 작업 유형 템플릿 ID: `4c34a6b5-a079-4ef0-b2d0-fabaa31b895e`

### 필수 필드 기본값
| 필드 | 기본값 | 비고 |
|------|--------|------|
| 이름 | 사용자 입력 | |
| 에픽 | 사용자 지정 | notion-search로 URL 검색 |
| 유형 | `버그` | 이슈 해결 기본값 |
| 상태 | `작업 중` | 즉시 작업 시작 |
| 플랫폼 | `Frontend` | CRM Front 기본값 |
| 서비스 | `공비서-B2B` | CRM B2B 기본값 |
| 작업자 | `notion-search`로 사용자 검색 | 실행하는 사용자의 Notion ID |
| 스프린트 | 현재 스프린트 | 스프린트 DB에서 `스프린트 상태: 현재` 검색 |
| 스토리포인트 | 사용자 입력 또는 자체 판단 | |
| 마일스톤 | 없음 | |

### 스프린트 찾기
스프린트 DB: `collection://46bae361-b009-4ac3-b08e-db4dce33a941`
`notion-search`로 현재 시점 스프린트를 검색하거나, 이전 대화에서 확인된 스프린트 URL 사용.

### 생성 후
- `notion-fetch`로 생성된 페이지를 조회하여 `userDefined:ID` (GBIZ-XXXXX) 추출
- 사용자에게 보고: 백로그 ID, Notion 링크

---

## Step 2: 브랜치 & 워크트리 생성

### 규칙
- **브랜치명**: `GBIZ-{ID}-{영문-기능-설명}` (GBIZ- 접두사 대문자 유지, 기능 설명은 소문자+하이픈)
- **워크트리 이름**: 백로그 ID만 사용 (예: `GBIZ-26304`)
- **워크트리 경로**: `../GBIZ-{ID}` (gongbiz 폴더 레벨)
- **base branch**: `develop`

### 명령어
```bash
git fetch origin develop
git worktree add -b GBIZ-{ID}-{description} ../GBIZ-{ID} origin/develop
```

### 워크트리 생성 후
- **반드시 워크트리 디렉토리 내에서 모든 작업 수행**
- 파일 경로: `../GBIZ-{ID}/src/...`
- git 명령어: `cd ../GBIZ-{ID}` 후 실행

### 사용자에게 보고
- 워크트리 경로, 브랜치명, base commit

---

## Step 3: 작업 진행

### 코드 수정 절차
1. 이슈 원인 분석 (관련 파일 탐색 및 읽기)
2. Figma Handoff가 있으면 `get_design_context`로 직접 스펙 확인 (스크린샷 사용 금지)
3. 수정 방안 사용자에게 브리핑 (before/after 비교)
4. **사용자 확인 후** 코드 수정
5. 타입 체크: `CHANGED=$(git diff --name-only HEAD | tr '\n' '|' | sed 's/|$//'); npx tsc --noEmit 2>&1 | grep -E "${CHANGED}"` (변경된 파일 관련 에러만 확인)

### 커밋 규칙
- 메시지 형식: `fix(GBIZ-{ID}): 간결한 한글 설명` 또는 `feat(GBIZ-{ID}): 설명`
- COMMIT_CONVENTION.md 참조
- 복합 작업 시 타입별 커밋 분리
- **워크트리에서는 `HUSKY=0 git -c core.hooksPath=/dev/null` 필수** (hook PATH 이슈)

### 커밋 명령어
```bash
cd ../GBIZ-{ID}
git add <파일들>
HUSKY=0 git -c core.hooksPath=/dev/null commit -m "fix(GBIZ-{ID}): 설명"
```

---

## Step 4: PR 생성

**사용자가 PR 생성을 명시적으로 요청한 경우에만 실행.**

### PR 규칙 (이슈 해결 전용)
- **PR 제목**: `[CLAUDE] GBIZ-{ID} 변경사항 요약`
- **`--draft` 플래그 필수**
- **Assignee**: `{GitHub 사용자명}` (gh API로 할당)
- **base branch**: `develop`

### PR 본문 5섹션 필수

```markdown
## 🎯 작업 내용
- 변경사항 요약 (무엇을 왜 수정했는지)

## 📋 체크리스트
- [ ] 코드 리뷰 요청 전 self-review 완료
- [ ] 로컬에서 정상 동작 확인
- [ ] 영향받는 기능들 테스트 완료
- [ ] Lint/Type 체크 통과

## 🧪 테스트 방법
- 구체적 테스트 단계

## 📸 스크린샷
해당 없음 또는 before/after 스크린샷

## 💭 리뷰 요청사항
리뷰 포인트
```

### PR 생성 절차
```bash
# 1. 원격에 푸시 (워크트리에서)
cd ../GBIZ-{ID}
HUSKY=0 git -c core.hooksPath=/dev/null push -u origin GBIZ-{ID}-{description}

# 2. Draft PR 생성
gh pr create --draft --base develop \
  --title "[CLAUDE] GBIZ-{ID} 변경사항 요약" \
  --body "$(cat <<'EOF'
PR 본문 (5섹션)
EOF
)"

# 3. Assignee 할당 (gh pr edit가 실패하면 API 사용)
gh api repos/{org}/{repo}/issues/{PR번호}/assignees \
  --method POST --input - <<< '{"assignees":["{GitHub 사용자명}"]}'
```

### Notion 백로그 업데이트
- `notion-update-page`로 상태: `리뷰요청` 변경
- GitHub 풀 리퀘스트 필드에 PR URL 추가

---

## 롤백/정리

### PR 취소 시
```bash
gh pr close {PR번호} --delete-branch
```

### 워크트리 정리
```bash
cd {프로젝트 루트}
git worktree remove ../GBIZ-{ID} --force
git branch -D GBIZ-{ID}-{description}  # 로컬 브랜치도 삭제
```

### Notion 백로그 상태 원복
- `notion-update-page`로 상태를 `백로그` 또는 `보류`로 변경

---

## 주의사항
- 이 스킬은 이슈 해결 전용. 기능 개발은 `generate-backlog-branch` + `create-pr` 사용
- 에픽 브랜치/Page 브랜치 2단계 구조는 사용하지 않음 (단일 브랜치 → develop PR)
- **각 단계에서 사용자 확인을 받고 진행** (특히 Step 3 코드 수정, Step 4 PR 생성)
- 워크트리 내 husky hook은 PATH 이슈로 실패함 → `HUSKY=0 git -c core.hooksPath=/dev/null` 사용
- Figma 디자인 확인 시 `get_design_context`로 직접 노드 읽기 (스크린샷 사용 금지)

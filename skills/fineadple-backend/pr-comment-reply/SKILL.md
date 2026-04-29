---
name: fineadple-backend-pr-comment-reply
description: 특정 PR 코멘트에 reply를 다는 스킬. PR 번호와 코멘트를 확인하고 선택한 코멘트에 답글을 등록합니다.
---

# PR Comment Reply

특정 PR의 코멘트에 reply(답글)를 등록합니다.

## When to Use This Skill

사용 시점:
- "PR 코멘트에 답글 달아줘", "reply to PR comment", "/fineadple-backend-pr-comment-reply"
- PR 번호와 함께 사용 (예: "PR 1165 코멘트에 답글 달아줘")
- GitHub PR URL과 함께 사용 (예: "https://github.com/herren-official/fineadple-server/pull/1168")
- 코멘트 앵커 포함 URL도 지원 (예: `...pull/1168#discussion_r2916288769` -> 해당 코멘트 자동 선택)
- PR 번호 없이 호출 시 사용자에게 번호를 물어봄

## PR Comment Reply Workflow

### Step 1: PR 번호 확인

사용자 입력에서 PR 번호를 추출한다. 다음 형식을 모두 지원:

- **PR 번호**: `1168`, `PR 1168`, `#1168`
- **GitHub URL**: `https://github.com/herren-official/fineadple-server/pull/1168`
- **URL + 코멘트 앵커**: `https://github.com/herren-official/fineadple-server/pull/1168#discussion_r123456`

URL이 제공된 경우 정규식으로 PR 번호를 추출한다:
- 패턴: `github\.com/[^/]+/[^/]+/pull/(\d+)`
- URL에 `#discussion_r(\d+)` 앵커가 포함된 경우, 해당 코멘트 ID도 함께 추출하여 **Step 2~3을 건너뛰고** 해당 코멘트를 바로 대상으로 선택한다.
- URL에 `#issuecomment-(\d+)` 앵커가 포함된 경우, 해당 일반 코멘트 ID도 함께 추출한다.
- **입력값 검증**: 추출된 PR 번호와 코멘트 ID는 반드시 숫자(`\d+`)인지 검증한다. 숫자가 아닌 값이 포함된 경우 사용자에게 올바른 값을 다시 요청한다.

코멘트 ID가 URL에서 추출된 경우, 해당 코멘트 내용만 조회하여 확인 후 바로 Step 4로 진행:
```bash
# 특정 리뷰 코멘트 조회 (discussion_r에서 추출한 ID)
gh api repos/herren-official/fineadple-server/pulls/comments/{COMMENT_ID} \
  --jq '{id, user: .user.login, path, line: (.line // .original_line), body}'

# 특정 일반 코멘트 조회 (issuecomment에서 추출한 ID)
gh api repos/herren-official/fineadple-server/issues/comments/{COMMENT_ID} \
  --jq '{id, user: .user.login, body, created_at}'
```

사용자가 PR 번호를 제공하지 않은 경우 물어본다.

### Step 2: PR 코멘트 목록 조회 (코멘트 ID가 없는 경우만)

리뷰 코멘트(인라인)와 일반 코멘트를 모두 가져온다.

```bash
# 리뷰 코멘트 (인라인 코멘트) 조회
gh api repos/herren-official/fineadple-server/pulls/{PR_NUMBER}/comments \
  --jq '.[] | {id, user: .user.login, path, line: (.line // .original_line), body: (.body | split("\n")[0:3] | join("\n")), in_reply_to_id, created_at}'

# 일반 이슈 코멘트 조회
gh api repos/herren-official/fineadple-server/issues/{PR_NUMBER}/comments \
  --jq '.[] | {id, user: .user.login, body: (.body | split("\n")[0:3] | join("\n")), created_at}'
```

### Step 3: 코멘트 목록 출력

조회된 코멘트를 보기 좋게 정리하여 출력한다.

출력 포맷:
```
## PR #{PR_NUMBER} 코멘트 목록

### 리뷰 코멘트 (인라인)
| # | ID | 작성자 | 파일 | 라인 | 내용 (미리보기) |
|---|-----|--------|------|------|-----------------|
| 1 | 123 | user1 | src/Main.java | 42 | 이 부분 수정 필요... |

### 일반 코멘트
| # | ID | 작성자 | 내용 (미리보기) |
|---|-----|--------|-----------------|
| 1 | 456 | user2 | LGTM 입니다... |
```

그 후 사용자에게 질문:
"어떤 코멘트에 답글을 달까요? (번호 또는 ID를 알려주세요)"

### Step 4: 답글 내용 작성

사용자가 답글 내용을 제공하지 않은 경우:
- 코멘트 전문을 보여주고 답글 내용을 물어본다

사용자가 답글 내용을 제공한 경우:
- 바로 Step 5로 진행

### Step 5: 관련 커밋 정보 조회 및 답글 포맷 생성

답글에 관련 커밋 해시를 포함하여 어떤 커밋에서 수정했는지 추적 가능하게 한다.

#### 5-1. 대상 파일의 최근 커밋 조회

코멘트가 달린 파일(`path`)에 대해 PR 브랜치의 최근 커밋을 조회한다:

```bash
# PR 브랜치명 확인
gh pr view {PR_NUMBER} --repo herren-official/fineadple-server --json headRefName --jq '.headRefName'

# 해당 파일의 최근 커밋 조회 (PR 브랜치 기준, develop 이후)
git log origin/develop..origin/{HEAD_BRANCH} --oneline -- {FILE_PATH}
```

가장 최근 커밋(HEAD 쪽)이 해당 코멘트에 대한 수정 커밋일 가능성이 높다.

#### 5-2. 답글 포맷

답글은 다음 형식으로 작성한다:

```
{설명} ({commit_short_hash})
```

예시:
- `수정 완료 — 미사용 logger, companion object, import 제거 (bcbcec1bf)`
- `수정 완료 — val now = LocalDateTime.now()로 통일 (d8fe82a85)`
- `현행 유지 — RECOVERING 대상 건수가 소량이고 배치 주기가 1일 1회이므로 성능 영향 미미.`

규칙:
- **수정한 경우**: `수정 완료 — {수정 내용 요약} ({commit_short_hash})` 형식 사용
- **현행 유지하는 경우**: `현행 유지 — {사유}` 형식 사용 (커밋 해시 불필요)
- 커밋 해시는 9자리 short hash 사용
- 사용자가 직접 답글 내용을 지정한 경우에도 관련 커밋이 있으면 `({commit_short_hash})` 를 끝에 붙여줄지 사용자에게 제안

### Step 6: 답글 등록 전 확인

등록할 내용을 미리보기로 출력:
```
대상 코멘트: #{comment_id} by {user} - "{코멘트 미리보기}"
관련 커밋: {commit_short_hash} {commit_message}
답글 내용:
---
{reply_body}
---

이 내용으로 답글을 등록할까요?
```

### Step 7: 답글 등록

승인 시 코멘트 유형에 따라 적절한 API를 사용한다.

#### 리뷰 코멘트(인라인)에 답글:

```bash
gh api repos/herren-official/fineadple-server/pulls/{PR_NUMBER}/comments/{COMMENT_ID}/replies \
  -X POST \
  -f body='{reply_body}'
```

#### 일반 이슈 코멘트에 답글:

일반 이슈 코멘트는 GitHub API에서 thread reply를 지원하지 않으므로, 원본 코멘트를 인용하여 새 코멘트를 등록한다.

```bash
gh api repos/herren-official/fineadple-server/issues/{PR_NUMBER}/comments \
  -X POST \
  -f body='> {원본 코멘트 첫 줄 인용}

{reply_body}'
```

### Step 8: 완료

등록된 답글의 URL을 출력한다.

## Workflow Examples

### 예시 1: PR 번호만 제공

사용자: "PR 1165 코멘트에 답글 달아줘"

1. PR 번호: 1165
2. `gh api repos/.../pulls/1165/comments` -> 리뷰 코멘트 목록
3. `gh api repos/.../issues/1165/comments` -> 일반 코멘트 목록
4. 코멘트 목록 출력 -> "어떤 코멘트에 답글을 달까요?"
5. 사용자: "1번, 수정했습니다"
6. 미리보기 출력 -> "이 내용으로 답글을 등록할까요?"
7. 승인 시 `gh api` 실행
8. 답글 URL 반환

### 예시 2: 코멘트 앵커 포함 URL 제공

사용자: "https://github.com/herren-official/fineadple-server/pull/1169#discussion_r2921399486 에 답글 달아줘"

1. URL 파싱 -> PR 번호: 1169, 코멘트 ID: 2921399486
2. `gh api repos/.../pulls/comments/2921399486` -> 해당 코멘트 내용 조회 (Step 2~3 건너뜀)
3. 코멘트: "미사용 logger 프로퍼티" (파일: `FollowerRecoveryCheckBatch.kt`)
4. `git log origin/develop..origin/{branch} --oneline -- {file_path}` -> 최근 커밋 조회
5. 관련 커밋: `bcbcec1bf 미사용 logger 제거`
6. 답글 자동 생성: `수정 완료 — 미사용 logger, companion object, import 제거 (bcbcec1bf)`
7. 미리보기 출력 -> "이 내용으로 답글을 등록할까요?"
8. 승인 시 `gh api .../comments/2921399486/replies` 실행
9. 답글 URL 반환

## Troubleshooting

**Issue**: gh CLI 미설치
- **Solution**: `brew install gh` (macOS) 안내

**Issue**: PR 번호가 없는 경우
- **Solution**: 사용자에게 PR 번호 요청

**Issue**: 코멘트가 없는 경우
- **Solution**: "이 PR에는 코멘트가 없습니다" 안내

**Issue**: 권한 부족
- **Solution**: `gh auth status`로 인증 상태 확인 안내

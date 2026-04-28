---
name: b2b-backend-view
description: 내가 작성한 open GitHub PR 중 리뷰가 필요한 PR의 미답변(unresolved) 코멘트만 조회한다. "view", "내 PR 코멘트", "미답변 코멘트" 요청 시 트리거.
---

# view

내가 작성한 open GitHub PR 중 리뷰가 필요한 PR의 미답변 코멘트만 조회해준다.

## 절차

1. 조회 대상 PR 선별:
   - 인자 없음:
     1. `gh pr list --author @me --state open --json number,title,url,headRefName,reviewDecision`로 내가 author인 open PR 전체 조회
     2. **내가 리뷰어로만 지정된 PR은 제외** (그건 `/b2b-backend-checkpr`에서 처리)
     3. 각 PR에 대해 unresolved 리뷰 스레드가 존재하는지 확인
     4. **아래 조건 중 하나라도 만족하면 조회 대상**:
        - `reviewDecision != "APPROVED"` (미승인 PR)
        - `reviewDecision == "APPROVED"`이지만 unresolved 스레드가 1개 이상 존재 (승인 후 추가 리뷰 들어온 경우)
   - 인자가 숫자 → 해당 PR 번호만 조회 (승인 여부 무시하고 조회)
   - 인자가 문장 → 맥락 파악해서 PR 특정. 모호하면 사용자에게 확인.

2. 각 PR의 리뷰 코멘트 가져오기:
   - 리뷰 스레드(resolved 여부 포함)는 GraphQL로 조회:
     ```graphql
     query {
       repository(owner: "...", name: "...") {
         pullRequest(number: ...) {
           reviewThreads(first: 100) {
             nodes {
               isResolved
               comments(first: 50) { nodes { id databaseId author { login } body path line createdAt } }
             }
           }
         }
       }
     }
     ```
   - 리뷰 본문: `gh api repos/{owner}/{repo}/pulls/{pr_number}/reviews`
   - 일반 코멘트: `gh api repos/{owner}/{repo}/issues/{pr_number}/comments`
   - username 확인: `gh api user --jq '.login'`

3. 필터링:
   - **resolved 스레드의 코멘트는 제외**
   - 내가 작성한 코멘트 제외
   - 봇(`coderabbitai[bot]`, `claude[bot]`, `notion-workspace[bot]` 등)의 자동 안내 코멘트는 맥락에 따라 유지/제외 판단

## 출력 형식

```
### PR: [제목] (#번호)
https://github.com/.../pull/번호

#### 💬 #코멘트ID (by @작성자) - `파일경로` L라인
> 코멘트 내용
↳ 답글 있으면 표시

---
```

## 규칙
- **미답변(unresolved) 코멘트만** 본문에 노출. resolved는 아예 출력하지 않음.
- 코멘트 ID 표시해서 `/b2b-backend-reply`에서 참조 가능하게.
- 미답변 코멘트 없는 PR은 출력 생략.
- APPROVED PR이 포함됐다면 상단에 "(APPROVED, 추가 리뷰 있음)" 표시로 구분.
- 조회 대상 PR이 없거나 모두 처리 완료면 "조회할 리뷰 코멘트가 없습니다" 출력.

$ARGUMENTS

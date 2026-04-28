---
name: b2b-backend-reply
description: 현재 브랜치에 연결된 GitHub PR의 미답변 리뷰 코멘트에 답글을 작성한다. "reply", "PR 답글", "리뷰 답변" 요청 시 트리거. 사용자 승인 후에만 게시.
---

# reply

현재 브랜치에 연결된 GitHub PR의 리뷰 코멘트에 답글을 달아준다.

## 절차

1. `gh pr view --json number,title,url`로 현재 브랜치의 PR 정보 가져오기.
2. PR 번호로 리뷰 코멘트 가져오기:
   - `gh api repos/{owner}/{repo}/pulls/{pr_number}/comments`
   - `gh api repos/{owner}/{repo}/issues/{pr_number}/comments`
3. 내 username(`gh api user --jq '.login'`)이 아닌 미답변 코멘트 필터링.
4. 각 코멘트의 관련 코드를 읽어서 맥락 파악.
5. 답글 초안 작성 후 사용자 확인받고 게시.

## 답글 형식

```
@{코멘트작성자}
반영하였습니다. {답글 내용}
{커밋해시}
감사합니다.
```

- 반드시 `@작성자`로 태그 시작.
- 한국어로 간결하게 작성.
- 코드 반영 시 관련 커밋 해시를 포함할 것.

## 게시 방법

1. 먼저 코멘트에 👍 리액션 추가: `gh api repos/{owner}/{repo}/pulls/comments/{comment_id}/reactions -f content="+1"`
2. 그 다음 답글 게시:
   - 인라인 코멘트: `gh api repos/{owner}/{repo}/pulls/{pr_number}/comments/{comment_id}/replies -f body="내용"`
   - 일반 코멘트: `gh api repos/{owner}/{repo}/issues/{pr_number}/comments -f body="내용"`

## 규칙

- ⛔ **사용자 확인 없이 절대 게시하지 마. 이 규칙은 어떤 상황에서도 예외 없이 적용된다.**
- ⛔ **답글 초안을 먼저 텍스트로 보여주고, 사용자가 명시적으로 승인한 후에만 `gh api`로 게시해라.**
- 코멘트 관련 코드를 반드시 읽고 맥락 파악 후 작성.

$ARGUMENTS

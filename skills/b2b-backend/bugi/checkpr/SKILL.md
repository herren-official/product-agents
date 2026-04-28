---
name: b2b-backend-checkpr
description: 내가 리뷰어로 지정된 open PR을 순차적으로 코드 리뷰한다. "checkpr", "내가 리뷰할 PR", "리뷰 대기 PR" 요청 시 트리거. 이전 리뷰 코멘트 반영 현황도 함께 확인한다.
---

# checkpr

내가 리뷰어로 지정된 open PR을 순차적으로 코드 리뷰해준다.

## 저장소

- `<owner>/<repo>`

## 절차

### Step 0: 이전 리뷰 코멘트 반영 확인

내가 리뷰한 적 있는 open PR에서 이전에 내가 달았던 인라인 코멘트가 수정 반영되었는지 확인한다.

> **주의**: `reviewRequests`에는 리뷰 제출 후 빠지므로, Step 1의 리뷰어 목록과 별도로 조회해야 한다.

```bash
# 1) 내가 리뷰한 open PR 목록 조회 (리뷰어 지정 여부와 무관)
gh search prs --repo <owner>/<repo> --state open --reviewed-by <github-username> --json number,title,author

# 2) 각 PR에서 내가 단 리뷰 코멘트 조회 (id, 답글 관계, 링크 포함)
gh api repos/<owner>/<repo>/pulls/{PR_NUMBER}/comments --jq '.[] | select(.user.login=="<github-username>") | {id, in_reply_to_id, path, line, body, html_url, created_at}'

# 3) 내 코멘트에 달린 답글 조회 (PR 작성자 등의 응답)
gh api repos/<owner>/<repo>/pulls/{PR_NUMBER}/comments --jq '.[] | select(.in_reply_to_id != null) | {id, in_reply_to_id, user: .user.login, body, created_at}'
```

각 코멘트에 대해:
1. 해당 파일/라인의 현재 코드를 확인 (`gh pr diff`)
2. 내 코멘트의 `id`를 기준으로 `in_reply_to_id`가 일치하는 답글을 매칭
3. 코멘트에서 지적한 내용이 수정되었는지 판단
4. 결과를 보여준다:

```
## 📌 이전 리뷰 코멘트 반영 현황

### PR #5117 (@author)
| # | 파일 | 코멘트 내용 | 답글 | 반영 | 링크 |
|---|------|------------|------|------|------|
| 1 | SaleService.kt:42 | null 체크 필요 | @author: 수정했습니다! | ✅ 반영됨 | [보기](html_url) |
| 2 | BookingController.kt:15 | 트랜잭션 분리 | (없음) | ❌ 미반영 | [보기](html_url) |
```

- 미반영 항목이 있으면 사용자에게 알려주고, 리뷰 진행 여부를 확인한다.

### Step 1: Open PR 수집

내가 리뷰어로 지정된 open PR만 조회한다.

```bash
gh pr list --repo <owner>/<repo> --state open --json number,title,url,headRefName,baseRefName,additions,deletions,changedFiles,isDraft,author,reviewRequests --jq '.[] | select(.reviewRequests[]?.login == "<github-username>") | select(.isDraft == false)'
```

- draft PR은 제외한다.
- 결과를 작성자별로 정리하여 목록을 보여준다.
- 가장 오래된 PR부터 순서대로 리뷰한다.

### Step 2: 리뷰 순서 확인

수집된 PR 목록을 보여주고 사용자에게 확인한다.

```
## 리뷰 대상 PR 목록

### 작성자A (@authorA)
1. #5117 - [CRM] 매출 테이블 컬럼 삭제 (+10 -5, 3 files)
2. #5120 - [CRM] 예약 결제 수정 (+30 -12, 5 files)

총 N개 PR을 순차 리뷰합니다. 진행할까요?
```

### Step 3: 순차 리뷰 실행

각 PR을 하나씩 `/b2b-backend-reviewer` 커맨드를 실행하여 리뷰한다.

```
/b2b-backend-reviewer {pr_url}
```

리뷰 결과를 보여주기 전에, PR body에서 문제/원인/영향 범위를 추출하여 간단히 요약한다:

```
### 📋 PR 배경
- **문제**: (PR body의 이슈/배경에서 추출)
- **원인**: (PR body의 원인 분석에서 추출)
- **영향 범위**: (있으면 표시)
```

이후 reviewer의 리뷰 결과를 이어서 출력한다.

- 각 PR 리뷰 완료 후 다음 PR로 넘어가기 전에 사용자에게 확인한다.

### Step 4: 전체 요약

모든 PR 리뷰 완료 후 전체 요약을 출력한다.

```
## ✅ 리뷰 완료 요약

| # | PR | 작성자 | Critical | Warning | Suggestion |
|---|-----|--------|----------|---------|------------|
| 1 | #5117 | @authorA | 0 | 2 | 1 |
| 2 | #5120 | @authorA | 1 | 0 | 3 |

총 N개 PR / Critical N건 / Warning N건 / Suggestion N건
```

### Step 5: PR 인라인 코멘트 등록

각 PR 리뷰 결과를 보여준 후, 사용자가 댓글 달 항목을 선택한다.

- "1, 3번만 달아줘", "Critical만 달아줘", "전부 달아줘" 등으로 선택
- 선택하지 않으면 다음 PR로 넘어간다.

선택된 항목을 `gh api`로 PR 인라인 코멘트로 등록한다.

```bash
gh api repos/<owner>/<repo>/pulls/{PR_NUMBER}/reviews \
  -X POST \
  --input - <<'EOF'
{
  "event": "COMMENT",
  "comments": [
    {
      "path": "{파일경로}",
      "line": {라인번호},
      "body": "{코멘트 내용}"
    }
  ]
}
EOF
```

#### 인라인 코멘트 톤 & 포맷

질문형을 섞어 동료가 대화처럼 느낄 수 있는 부드러운 톤으로 작성한다.
코드 제안은 포함하지 않는다.

예시:
```
@author 여기서 null 체크 없이 접근하고 있는데, nullable인 경우도 있을까요?
혹시 그렇다면 방어 로직 추가하면 좋을 것 같습니다.
```

```
@author 트랜잭션 범위 안에 외부 API 호출이 포함되어 있는 것 같은데, 의도한 건가요?
분리하면 롤백 범위가 줄어들어서 안전할 것 같습니다.
```

## 규칙

- 리뷰 기준과 출력 형식은 reviewer 커맨드의 규칙을 따른다.
- 각 PR 리뷰 완료 후 다음 PR로 넘어가기 전에 사용자에게 확인한다.
- 인라인 코멘트는 반드시 사용자가 선택한 항목만 등록한다.
- 코멘트에 코드 제안을 포함하지 않는다.
- 코멘트 앞에 PR 작성자를 @태그한다.

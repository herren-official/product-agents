---
name: b2b-backend-chain-status
description: 체이닝 브랜치 상태 확인 (git base, PR 상태, 리뷰 현황)
argument-hint: [base-branch]
user-invocable: true
allowed-tools: Bash, Read
---

현재 브랜치를 기준으로 체이닝 브랜치의 상태를 확인해라.

## 입력

$ARGUMENTS

- 인자가 브랜치명이면 해당 브랜치를 체인의 최상위(root)로 사용한다.
  - 해당 브랜치가 로컬/리모트에 존재하지 않으면 에러를 출력하고 종료한다.
- 인자가 없으면 다음 순서로 체인 정보를 찾는다:
  1. memory 디렉토리에서 `branch-status` 또는 `브랜치 체인`이 포함된 md 파일을 검색한다.
  2. 메모리에 없으면 `gh pr view --json baseRefName,headRefName`으로 현재 브랜치의 PR을 확인하고, baseRefName을 따라 상위를 추적한다.
  3. PR도 없으면 "현재 브랜치에 연결된 PR이 없습니다. base 브랜치를 인자로 지정해 주세요."를 출력하고 종료한다.

## 절차

### Step 1: 체인 구조 파악

**상위 추적**: 현재 브랜치에서 `gh pr view {branch} --json baseRefName --jq '.baseRefName'`을 반복하여 상위 브랜치를 추적한다.
**하위 추적**: `gh pr list --base {branch} --state open --json headRefName,number`로 해당 브랜치를 base로 사용하는 PR을 찾는다.
**종료 조건**: base가 develop, main, master, 또는 epic-* 패턴 브랜치이면 상위 탐색을 종료한다.
**깊이 제한**: 최대 20단계까지만 탐색한다. 초과 시 "[최대 탐색 깊이 도달]"을 표시한다.

### Step 2: 각 브랜치 상태 확인

각 브랜치에 대해 다음을 수집한다:
- **PR 정보**: `gh pr view {branch} --json number,title,state,reviewDecision,latestReviews`
- **리뷰 상태**: reviewDecision (APPROVED / CHANGES_REQUESTED / REVIEW_REQUIRED)
- **리뷰어별 상태**: latestReviews에서 리뷰어별 가장 최근 상태만 추출
- **git 체인 정합성**: `git merge-base {child} {parent}`가 parent의 HEAD와 일치하는지 확인. 불일치 시 "rebase 필요"로 표시
- **로컬/리모트 동기화**: `git rev-list --left-right --count {local}...origin/{branch}` (ahead/behind)

### Step 3: 미답변 리뷰 코멘트 확인

각 PR에 대해:
- `gh api repos/{owner}/{repo}/pulls/{number}/comments`로 인라인 코멘트를 조회한다.
- PR author의 답글(`in_reply_to_id`가 있고 `user.login`이 PR author)이 없는 top-level 리뷰 코멘트를 미답변으로 판정한다.
- 봇 계정(`user.type`이 `Bot`)의 코멘트는 제외한다.

## 출력 형식

### 1. 체인 구조 트리
```
{root-branch}
 └─ #{number} {branch} ({설명}) [{state}]
     └─ #{number} {branch} ({설명}) [{state}]  ← 현재
         └─ #{number} {branch} ({설명}) [{state}]
```
- 현재 브랜치에 `← 현재`를 표시한다.

### 2. 상세 현황 테이블
| PR | 브랜치 | 상태 | 리뷰 | 리뷰어 | git base | 동기화 | 미답변 |
|----|--------|------|------|--------|----------|--------|--------|

### 3. 주의 사항 (해당 항목이 있을 때만 출력)
- rebase가 필요한 브랜치 목록
- 미답변 코멘트가 있는 PR 목록

## 제약

- 코드를 수정하지 않는다. 상태 확인만 수행한다.
- PR이 없는 브랜치는 "(PR 없음)"으로 표시한다.
- 메모리 파일에 브랜치 체인 정보가 있으면 참고하되, 실제 gh/git 명령 결과를 우선한다.

---
name: b2b-backend-pr-chain-rebase
description: PR 체인 브랜치들을 순서대로 리베이스하고 force push
argument-hint: [PR번호 또는 브랜치명]
---

PR 체인 브랜치들을 순서대로 리베이스하고 force push한다.

## 사용법

/pr-chain-rebase [PR번호 또는 브랜치명]

- PR 번호(예: 1234) 또는 브랜치명(예: feature/foo)을 인자로 받는다.
- 인자가 없으면 현재 체크아웃된 브랜치 기준으로 동작한다.

## 실행 절차

### 1. 대상 브랜치 결정

- 인자가 숫자이면 PR 번호로 간주하고, `gh pr view {번호} --json headRefName -q .headRefName`으로 브랜치명을 가져온다.
- 인자가 문자열이면 브랜치명으로 사용한다.
- 인자가 없으면 `git branch --show-current`로 현재 브랜치를 사용한다.

### 2. PR 체인 구조 파악

- 시작 브랜치에서 출발하여 `gh pr list --head {branch} --json number,baseRefName,headRefName` 및 `gh pr list --base {branch} --json number,baseRefName,headRefName`을 재귀적으로 호출하여 체인 전체를 탐색한다.
- 각 PR의 base 브랜치를 추적하여 체인의 루트(develop 또는 main 등 최종 base)까지 올라간다.
- 동시에 하위 방향으로도 탐색하여 현재 브랜치 아래에 달린 PR들도 포함한다.
- 최종적으로 루트에서 리프까지의 순서가 정해진 브랜치 리스트를 만든다.

### 3. 리베이스 순서 결정

- 체인 구조를 최상위(base에 가까운 쪽)부터 하위(리프) 순서로 정렬한다.
- 예: `develop <- A <- B <- C` 이면 리베이스 순서는 A -> B -> C

### 4. 순서대로 리베이스 및 push

각 브랜치에 대해 다음을 순서대로 실행한다:

```bash
git fetch origin {base_branch}
git checkout {branch}
git rebase {base_branch}
git fetch origin {branch}
git push origin {branch} --force-with-lease
```

- 리베이스 충돌 발생 시 즉시 `git rebase --abort`를 실행하고, 해당 브랜치에서 중단한다.
- 충돌이 발생한 브랜치와 충돌 내용을 사용자에게 알린다.
- 충돌 이후의 나머지 브랜치는 스킵한다.

### 5. 완료 후 요약

모든 브랜치 처리가 끝나면 아래 형식으로 요약을 출력한다:

```
## PR Chain Rebase 결과

| 브랜치 | Base | PR | 상태 |
|--------|------|----|------|
| feature/a | develop | #101 | 성공 |
| feature/b | feature/a | #102 | 성공 |
| feature/c | feature/b | #103 | 충돌 (중단) |
| feature/d | feature/c | #104 | 스킵 |
```

- 리베이스 전에 체크아웃했던 원래 브랜치로 복귀한다.

## 주의사항

- `--force-with-lease`를 사용하므로, 다른 사람이 push한 변경이 있으면 push가 실패할 수 있다. 이 경우 사용자에게 알린다.
- 로컬에 없는 브랜치는 fetch로 가져온 뒤 작업한다.
- 체인에 포함된 PR이 이미 merged 상태이면 해당 브랜치는 스킵한다.

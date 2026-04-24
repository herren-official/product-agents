---
name: b2c-ios-review-fix
description: "현재 브랜치의 PR 코멘트를 분석하고 코드를 수정합니다"
argument-hint: "[특정 코멘트만 처리할 경우 키워드]"
disable-model-invocation: false
allowed-tools: ["Bash", "Read", "Edit", "Grep", "Glob"]
---

# PR 코멘트 리뷰 반영

## 실행 알림
이 스킬이 실행되면 가장 먼저 "[review-fix] 스킬이 실행되었습니다."를 출력할 것

$ARGUMENTS

## 0. 현재 상태 (동적 주입)

### 현재 브랜치
!`git branch --show-current`

### GBIZ 번호
!`git branch --show-current | grep -oE "GBIZ-[0-9]+" | head -1 || echo "GBIZ 번호 없음"`

### 현재 브랜치의 PR 번호
!`gh pr list --head "$(git branch --show-current)" --json number,title,url --jq '.[] | "#\(.number) \(.title) \(.url)"' 2>/dev/null || echo "PR 없음"`

### 커밋되지 않은 변경사항
!`git status --porcelain`

## 실행 프로세스

### 1단계: 사전 확인

- PR이 없으면 중단하고 안내
- 커밋되지 않은 변경사항이 있으면 먼저 처리 여부 확인

### 2단계: PR 코멘트 수집

PR 번호를 이용하여 리뷰 코멘트를 수집:

```bash
# 일반 코멘트
gh api repos/{owner}/{repo}/issues/{pr_number}/comments --jq '.[] | {id: .id, user: .user.login, body: .body}'

# 리뷰 코멘트 (코드 라인에 달린 코멘트)
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments --jq '.[] | {id: .id, user: .user.login, path: .path, line: .line, body: .body, in_reply_to_id: .in_reply_to_id}'
```

### 3단계: 코멘트 분류

각 코멘트를 분석하여 분류:
- **코드 수정 필요**: 구체적인 코드 변경 요청 (버그 지적, 네이밍 변경, 로직 수정 등)
- **재확인 대기 중**: 이전에 "by. Claude" 답글을 달았으나 리뷰어가 아직 반응하지 않은 코멘트
- **질문/논의**: 코드에 대한 질문이나 논의 사항
- **칭찬/확인**: 수정 불필요한 코멘트 (LGTM, 좋아요 등)

**재확인 대기 판별 방법:**
- 코멘트 스레드의 마지막 답글이 "by. Claude"로 끝나는 경우
- 다음 중 하나에 해당하면 재촉 대상:
  - 그 이후 리뷰어의 추가 답글, 이모지 리액션 등 어떤 반응도 없는 경우
  - 이모지 리액션은 있으나 텍스트 답글 없이 10분 이상 경과한 경우 (by. Claude 답글의 `created_at` 기준)

**미해결(unresolved) thread 판별 (매우 중요):**
- GraphQL API로 `isResolved == false`인 thread를 반드시 확인
- 리뷰어(CodeRabbit 등)가 "by. Claude" 답글 이후 **추가 답글을 달았으면 재촉이 아니라 내용을 반드시 전문 확인**
- 리뷰어의 추가 답글에 **구체적인 수정 요청이 있으면 "코드 수정 필요"로 재분류**
- 단순히 thread 상태(resolved/unresolved)만 보고 기계적으로 재촉하지 않는다
- unresolved thread 확인 명령:
```bash
gh api graphql -f query='{ repository(owner: "{owner}", name: "{repo}") { pullRequest(number: {pr_number}) { reviewThreads(last: 50) { nodes { isResolved comments(first: 10) { nodes { databaseId author { login } body } } } } } } }' --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false)'
```

코드 수정이 필요한 코멘트만 추출하여 목록화

### 4단계: 실제 코드/환경 검증 (중요 - 모든 코멘트 필수)

**3단계에서 분류된 모든 코멘트**에 대해 실제 코드와 환경을 검증한다.
추측이나 문서 내용만으로 판단하지 말고 반드시 실제 소스를 확인한 뒤 결론을 내린다.

1. **코멘트가 가리키는 파일/라인의 현재 코드 확인**
   - 코멘트가 작성된 시점과 현재 코드가 다를 수 있음 (이미 수정된 경우)
   - 실제 코드를 Read/Grep으로 직접 확인

2. **리뷰어 지적의 정확성 검증**
   - 리뷰어가 참조한 코드/동작이 실제와 일치하는지 확인
   - 자동 리뷰 봇(CodeRabbit 등)의 분석이 잘못된 경우가 있음
   - 외부 환경(GitHub 라벨, API 응답 등)에 의존하는 지적은 `gh` CLI 등으로 실제 상태를 조회하여 확인
   - 예: 라벨에 이모지 포함 여부 → `gh label list`로 확인

3. **"리뷰어 오판" 판정 전 필수 검증**
   - 리뷰어가 틀렸다고 판단하기 전에 반드시 실제 코드/환경에서 근거를 확보
   - 근거 없이 "우리가 맞다"고 답글 달지 않음
   - 검증에 사용한 명령어와 결과를 5단계에서 사용자에게 제시

4. **검증 결과에 따라 재분류**
   - **수정 필요 (검증 완료)**: 실제 코드 확인 결과 수정이 맞음
   - **이미 수정됨**: 후속 커밋에서 이미 처리된 코멘트 → 재확인 요청 답글
   - **리뷰어 오판 (근거 확보)**: 실제 코드/환경과 맞지 않는 지적 → 근거와 함께 재확인 요청 답글

### 5단계: 검증 결과 제시

```
PR 코멘트 분석 결과:

[수정 필요 - 검증 완료] N건
1. path/to/File.swift:42 - @reviewer: "변수명을 camelCase로 변경해주세요"
   검증: 현재 코드에 user_name이 존재함 → 수정 필요

[이미 수정됨] N건
1. path/to/File.swift:88 - @reviewer: "타입 오류 수정 필요"
   검증: 커밋 abc1234에서 이미 수정됨 → 재확인 요청 답글 예정

[리뷰어 오판] N건
1. path/to/File.swift:100 - @reviewer: "이모지 제거 필요"
   검증: 실제 GitHub 라벨에 이모지 포함 → 재확인 요청 답글 예정

[재확인 대기 중] N건
1. path/to/File.swift:50 - @reviewer: "불필요한 import 제거"
   상태: by. Claude 답글 후 리뷰어 미응답 → 재촉 답글 예정

[질문/논의] N건
[수정 불필요] N건

수정 작업을 시작하시겠습니까? [Y/N]
```

사용자 승인 시:
- "수정 필요" 항목 → 코드 수정 진행 (6단계)
- "이미 수정됨" / "리뷰어 오판" / "재확인 대기 중" 항목 → push 후 답글 (9단계)

### 6단계: 개별 코멘트 처리 (반복)

각 수정 대상 코멘트에 대해 순차적으로:

1. **코멘트 내용과 해당 코드 표시**
2. **수정 방안 제시**
3. **사용자 컨펌 요청**

```
[1/N] path/to/File.swift:42
코멘트: "변수명을 camelCase로 변경해주세요" (@reviewer)

현재 코드:
  let user_name = "홍길동"

수정 제안:
  let userName = "홍길동"

[Y] 수정 / [N] 건너뛰기 / [E] 다른 방식으로 수정
```

4. **승인된 수정만 적용**

### 7단계: 컨벤션 검사 및 커밋

모든 수정이 완료되면:

1. **pre-commit-checker 실행**: 변경된 파일에 대해 컨벤션 검사 수행
   - 위반 사항 발견 시 수정 후 재검사
   - 모든 검사 통과 확인

2. **커밋 진행**:
   - 변경된 파일을 개별 스테이징 (git add . 금지)
   - 커밋 타입: `review`
   - 커밋 메시지 형식:

```bash
git commit -m "$(cat <<'EOF'
review: PR 코드리뷰 반영

- 수정 내용 1
- 수정 내용 2

GBIZ-{번호}
EOF
)"
```

논리적으로 분리가 필요하면 여러 커밋으로 나누기

### 8단계: 푸시

사용자에게 "push를 진행해도 될까요?" 확인 후 진행:

```bash
git push
```

### 9단계: 답글 작성 (push 이후 필수)

> **중요**: 반드시 push 완료 후에 답글을 작성한다.
> CodeRabbit 등 자동 리뷰 봇은 답글 시점에 코드를 재확인하므로,
> push 전에 답글을 달면 수정되지 않은 코드를 확인하여 동일 지적이 반복된다.

`gh api`로 코멘트 타입에 맞춰 답글을 작성한다:

```bash
# 리뷰 코멘트 (코드 라인에 달린 코멘트) → 스레드 답글
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments/{comment_id}/replies \
  -X POST -f body="답글 내용"

# 일반 코멘트 (PR 본문에 달린 코멘트) → 새 이슈 코멘트
gh api repos/{owner}/{repo}/issues/{pr_number}/comments \
  -X POST -f body="@{reviewer_login} 답글 내용"
```

> **"by. Claude" 서명 사용 이유**: PR 리뷰 컨텍스트에서는 리뷰어가 AI가 작성한 답글임을 인식할 수 있도록 투명하게 명시한다. 이는 CLAUDE.md의 "AI 도구 사용 흔적 금지" 규칙에서 의도적으로 예외를 두는 것이며, 커밋/PR 본문이 아닌 리뷰 답글에만 적용된다.

**수정 완료 답글:**
```
@{reviewer_login} [{short_hash}](https://github.com/{owner}/{repo}/commit/{full_hash})에서 {수정 내용 요약}으로 변경했습니다.

재확인 부탁합니다.
by. Claude
```

**이미 수정된 경우:**
```
@{reviewer_login} [{short_hash}](https://github.com/{owner}/{repo}/commit/{full_hash})에서 이미 수정되었습니다.

재확인 부탁합니다.
by. Claude
```

**리뷰어 오판인 경우:**
```
@{reviewer_login} 확인 결과 {근거 설명}.
{구체적 증거 (코드 스니펫, 명령어 결과 등)}

재확인 부탁합니다.
by. Claude
```

**재촉 (재확인 대기 중):**
```
@{reviewer_login} 리마인드 드립니다. 위 내용 재확인 부탁합니다.
by. Claude
```

> `{reviewer_login}`은 원본 코멘트의 `user.login` 값을 사용한다. (예: `@coderabbitai[bot]`, `@reviewer`)

## 금지 사항

- **Co-Authored-By 절대 금지**
- **`git add .` 또는 `git add -A` 사용 금지** - 개별 파일 경로로만 스테이징
- **커밋 메시지에 이모지 사용 금지**
- **사용자 컨펌 없이 코드 수정 금지**
- **코멘트 내용을 임의로 해석하여 과도한 수정 금지** - 코멘트가 요청한 범위만 수정

## 에러 처리

| 에러 | 대응 |
|------|------|
| PR 없음 | 현재 브랜치에 PR이 없으면 중단하고 안내 |
| 코멘트 수집 실패 | gh CLI 인증/권한 확인 요청 |
| 코드 파일 접근 불가 | 해당 파일이 삭제/이동되었는지 확인 |
| 커밋 실패 | 충돌 여부 확인, 사용자에게 보고 |

## 참조 문서

- 커밋 규칙: `.docs/COMMIT_CONVENTION.md`
- 코딩 컨벤션: `.docs/conventions/CONVENTIONS.md`

---
name: b2b-android-pr
description: PR 자동 생성. "PR 만들어줘", "풀리퀘스트 생성", "PR 올려줘" 요청 시 사용
allowed-tools: Bash, Read, Grep, AskUserQuestion, mcp__notionMCP__notion-search, mcp__notionMCP__notion-fetch, mcp__notionMCP__notion-update-page
user-invocable: true
---

# PR 생성 스킬

브랜치명에서 GBIZ 번호를 추출하여 Notion 작업 카드와 연동된 PR을 생성한다.

## 인자 분석

- **인자 없음**: 현재 브랜치에서 GBIZ 번호 추출, 부모 브랜치 자동 탐색 (실패 시 `dev`)
- **일반 브랜치명**: 해당 브랜치를 직접 base로 사용 (예: `b2b/8.10.17`)
- **GBIZ-NNNNN 패턴**: 해당 번호가 포함된 원격 브랜치를 base로 사용
- **숫자만 입력**: `20251` → `GBIZ-20251`로 변환하여 해당 브랜치를 base로 사용
- **4자리 숫자**: `8655` → `GBIZ-08655`로 변환 (앞에 0 자동 추가)

### 사용 예시
```bash
/pr                          # 현재 브랜치에서 자동으로 부모 브랜치 결정 (기본값: dev)
/pr dev                      # dev 브랜치를 base로 지정
/pr b2b/8.10.17              # b2b/8.10.17 브랜치를 base로 지정 (사용자 지정 우선)
/pr GBIZ-19448               # GBIZ-19448 브랜치를 base로 하여 현재 브랜치에서 PR 생성
/pr 20251                    # 숫자만 입력 → GBIZ-20251 브랜치를 base로 사용
/pr 8655                     # 4자리 숫자 → GBIZ-08655 브랜치를 base로 사용
```

## 실행 단계

### 1단계: 컨벤션 및 브랜치 정보 확인
```bash
git branch --show-current
git status --porcelain
git fetch --quiet
```

### 2단계: GBIZ 번호 추출
- 현재 브랜치명에서 `GBIZ-XXXXX` 패턴 추출
- 예: `shop-ux/GBIZ-23830-ui-calendar-setting` → `GBIZ-23830`

### 3단계: Base 브랜치 결정

**우선순위**:
1. 사용자가 명시적으로 지정한 브랜치 **(최우선)**
2. 인자로 전달된 GBIZ 번호의 브랜치 검색
3. 인자 없음 → 부모 브랜치 자동 탐색:
   - `git log --oneline --decorate`로 분기점 확인
   - 또는 브랜치 생성 기록 기반 추정
4. 탐색 실패 시 → `dev` 기본값

```bash
# 1. 최신 원격 브랜치 정보 가져오기 (필수)
git fetch --quiet

# 2. 사용자가 브랜치명을 직접 지정한 경우 (예: b2b/8.10.17)
if [[ -n "$ARGUMENTS" ]]; then
  # 지정된 브랜치가 원격에 있는지 확인
  if git branch -r | grep -q "origin/$ARGUMENTS"; then
    BASE_BRANCH="$ARGUMENTS"
    echo "사용자 지정 base 브랜치: $BASE_BRANCH"
  else
    # 숫자만 입력된 경우 GBIZ- 접두사 자동 추가
    if [[ "$ARGUMENTS" =~ ^[0-9]+$ ]]; then
      if [[ ${#ARGUMENTS} -eq 4 ]]; then
        GBIZ_NUMBER="GBIZ-0$ARGUMENTS"
      else
        GBIZ_NUMBER="GBIZ-$ARGUMENTS"
      fi
      # GBIZ 번호로 브랜치 검색
      BASE_BRANCH=$(git branch -r | grep "$GBIZ_NUMBER" | head -1 | sed 's/origin\///')
    fi
  fi
else
  # 3. 인자 없음 → 부모 브랜치 자동 탐색
  CURRENT=$(git branch --show-current)

  # 3-1. git log --oneline --decorate로 분기점 확인
  # 현재 브랜치가 갈라져 나온 원격 브랜치를 찾는다
  PARENT=$(git log --oneline --decorate --simplify-by-decoration "$CURRENT" \
    | grep -oP 'origin/\K[^,)]+' \
    | grep -v "^$CURRENT$" \
    | grep -v 'HEAD' \
    | head -1)

  # 3-2. 위 방법 실패 시 브랜치 생성 기록 기반 추정
  if [[ -z "$PARENT" ]]; then
    PARENT=$(git reflog show "$CURRENT" --format='%gs' \
      | grep 'branch: Created from' \
      | head -1 \
      | sed 's/.*Created from //' \
      | sed 's|^refs/heads/||' \
      | sed 's|^origin/||')
  fi

  if [[ -n "$PARENT" ]]; then
    # 찾은 부모 브랜치가 원격에 존재하는지 확인
    if git branch -r | grep -q "origin/$PARENT"; then
      BASE_BRANCH="$PARENT"
      echo "자동 탐색된 부모 브랜치: $BASE_BRANCH"
    else
      BASE_BRANCH="dev"
      echo "부모 브랜치 '$PARENT'가 원격에 없어 dev 사용"
    fi
  else
    # 4. 탐색 실패 시 dev 기본값
    BASE_BRANCH="dev"
    echo "부모 브랜치 탐색 실패, 기본값 dev 사용"
  fi
fi
```

**GBIZ 번호로 브랜치 검색 시**:
- 정확히 일치하는 브랜치 우선 선택
- 여러 브랜치 발견 시 가장 최근 브랜치 선택
- 찾은 브랜치를 base branch로 설정 (현재 브랜치는 변경하지 않음)
- 해당 GBIZ 번호의 브랜치가 없으면 안내 메시지 표시

**브랜치 컨벤션 기반 결정**:
- **feature 브랜치**: `dev` 브랜치를 base로 사용
- **hotfix 브랜치**: `main` 브랜치를 base로 사용
- **하위 feature 브랜치**: 상위 feature 브랜치를 base로 사용

### 4단계: Notion 카드 검색
GBIZ 번호로 Notion 작업 카드 검색하여 정보 수집:
- 제목, URL
- Figma 링크, API 문서 등 참고 링크

### 5단계: PR 정보 자동 생성 및 사용자 확인
- **제목 생성**: `[GBIZ-번호] {Notion 카드 제목에서 [CRM][Android] 등 플랫폼 태그 제외}`
- **본문 생성**: 아래 PR 본문 구조 참고
- **미리보기**: 생성된 PR 제목과 본문을 사용자에게 표시
- **수정 요청**: 사용자가 내용 수정을 요청하면 반영
- **승인 대기**: 사용자 승인 후 실제 PR 생성 진행
- **작업 사항 저장**: 승인된 작업 사항 내용을 변수에 저장 (Notion 업데이트용)

### 6단계: 기존 PR 확인
```bash
gh pr list --head $(git branch --show-current)
```
- 이미 PR 존재 시 → 링크 안내 후 종료
- 없으면 → 다음 단계 진행

### 7단계: Push 및 PR 생성

#### 7-1. Push 상태 확인 및 처리
```bash
# 원격 브랜치 존재 확인
git ls-remote --heads origin $(git branch --show-current)

# 로컬 커밋이 push되지 않았는지 확인
git log origin/$(git branch --show-current)..HEAD --oneline
```
- **원격 브랜치 없음**: `git push -u origin {브랜치명}`
- **Push되지 않은 커밋 있음**: `git push`

#### 7-2. Label 자동 설정
```bash
CURRENT_BRANCH=$(git branch --show-current)
LABEL=""

if [[ "$CURRENT_BRANCH" == *"test-"* ]]; then
  LABEL="Test"
elif [[ "$CURRENT_BRANCH" == *"feat-"* ]]; then
  LABEL="Feature"
elif [[ "$CURRENT_BRANCH" == *"fix-"* ]]; then
  LABEL="BugFix"
elif [[ "$CURRENT_BRANCH" == *"ui-"* ]]; then
  LABEL="UI"
elif [[ "$CURRENT_BRANCH" == *"refactor-"* ]]; then
  LABEL="Refactor"
elif [[ "$CURRENT_BRANCH" == *"docs-"* ]]; then
  LABEL="Document"
elif [[ "$CURRENT_BRANCH" == *"chore-"* ]]; then
  LABEL="Setting"
fi
```

| 브랜치 키워드 | Label |
|--------------|-------|
| `feat-` | Feature |
| `fix-` | BugFix |
| `ui-` | UI |
| `refactor-` | Refactor |
| `test-` | Test |
| `docs-` | Document |
| `chore-` | Setting |

#### 7-3. PR 생성
```bash
if [ -n "$LABEL" ]; then
  gh pr create \
    --base "{base-branch}" \
    --title "[GBIZ-번호] {제목}" \
    --body "$(cat <<'EOF'
PR 본문 내용...
EOF
)" \
    --label "$LABEL"
else
  gh pr create \
    --base "{base-branch}" \
    --title "[GBIZ-번호] {제목}" \
    --body "$(cat <<'EOF'
PR 본문 내용...
EOF
)"
fi
```

### 8단계: Notion 카드 업데이트
PR 생성 성공 후 **반드시** 실행:

#### 8-1. "GitHub 풀 리퀘스트" 속성 업데이트
```
mcp__notionMCP__notion-update-page
- properties: {"GitHub 풀 리퀘스트": "PR URL"}
```

#### 8-2. "### 내용" 섹션에 작업 사항 추가
```
mcp__notionMCP__notion-update-page
- command: insert_content_after
- 위치: "</callout>\n<empty-block/>\n### 참고"
- 내용: PR 작업 사항 리스트
```

추가할 내용 형식:
```markdown
### 내용
<callout icon="💡" color="gray_bg">
	작업 상세 내용으로 해야할 작업을 세분화하여 정리하여 작성한다
</callout>

{PR에서 작성한 작업 사항 리스트}
- 작업 항목 1
- 작업 항목 2
- ...
```

#### 8-3. "### 참고" 섹션에 PR 링크 추가
```
mcp__notionMCP__notion-update-page
- command: insert_content_after
- 위치: "external_object_instance\"/>...<empty-block/>\n---"
- 내용: "* [PR #번호](PR URL)"
```

## PR 제목 형식

```
[GBIZ-번호] PR 제목
```

- Notion 카드 제목에서 `[CRM]`, `[Android]` 등 플랫폼 태그 제외
- 예시:
  - `[GBIZ-23830] 캘린더 설정 UI 수정`
  - `[GBIZ-18655] 인센티브 설정 로직 추가`

## PR 본문 구조 (필수)

```markdown
## 작업 사항
- 구체적인 작업 내용 (변경 전 → 변경 후 형식 권장)
- 추가/수정/삭제된 기능 명시
<br>

## 확인 사항
- [ ] {메뉴 > 화면 경로} 진입 후 {확인할 내용}
- [ ] {테스트 시나리오}
<br>

## 기타
-
<br>

## 참고
* [GBIZ-번호](Notion 카드 URL)
* [Figma](Figma URL) # 있는 경우
* [API 문서](API 문서 URL) # 있는 경우
```

## 핵심 규칙

### ✅ 필수
- GBIZ 번호 대괄호로 감싸기: `[GBIZ-XXXXX]`
- 한글 제목 작성
- Notion 카드 링크 참고 섹션에 포함
- 확인 사항에 **화면 경로** 명시 (예: "캘린더 > 설정")
- Label 자동 설정
- **PR 생성 후 Notion 카드 3곳 업데이트**:
  1. GitHub 풀 리퀘스트 속성
  2. 내용 섹션
  3. 참고 섹션
- 브랜치 존재 여부 확인 전에 항상 `git fetch` 실행
- grep 결과를 신중하게 확인하여 브랜치 존재 여부 정확히 판단
- **사용자가 명시적으로 브랜치를 지정하면 무조건 해당 브랜치를 base로 사용**

### ⛔ 금지
- Assignee/Reviewers 자동 설정 (수동 지정)
- GBIZ 번호 없이 PR 생성
- Summary/Test plan 형식 사용 ❌ → 작업 사항/확인 사항 형식 사용 ✅

## 에러 처리
- **GBIZ 번호 없음**: 브랜치명에서 GBIZ 패턴을 찾을 수 없는 경우 안내
- **Notion 카드 없음**: 해당 GBIZ 번호의 작업 카드가 없는 경우 기본 템플릿 사용
- **Push 실패**: 네트워크 오류 등으로 push 실패 시 재시도 안내
- **PR 생성 실패**: gh CLI 오류 시 수동 생성 방법 안내
- **브랜치 없음**: 해당 GBIZ 번호의 브랜치가 없으면 안내 메시지 표시

## 상세 문서

컨벤션: [pr-convention.md](../../../.docs/conventions/pr-convention.md)

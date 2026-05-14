---
name: b2c-android-create-pr
description: "PR 자동 생성 - 노션 연동 및 PR 컨벤션 적용. Use when: PR 만들어줘, PR 올려줘, 풀리퀘스트 생성, PR 생성"
argument-hint: "[target-branch|GBIZ-NNNNN|숫자]"
allowed-tools: ["bash", "read", "grep", "mcp__notionMCP__notion-search", "mcp__notionMCP__notion-fetch", "mcp__notionMCP__notion-update-page"]
---

# PR 생성 스킬

브랜치명에서 GBIZ 번호를 추출하여 Notion 작업 카드와 연동된 PR을 생성한다.

## 인자 분석

- **인자 없음**: 현재 브랜치에서 GBIZ 번호 추출, 부모 브랜치 자동 탐색 (실패 시 `develop`)
- **일반 브랜치명**: 해당 브랜치를 직접 base로 사용 (예: `develop`, `epic-ai/main`, `qa`, `main`)
- **GBIZ-NNNNN 패턴**: 해당 번호가 포함된 원격 브랜치를 base로 사용
- **숫자만 입력**: `20251` → `GBIZ-20251`로 변환하여 해당 브랜치를 base로 사용
- **4자리 숫자**: `8655` → `GBIZ-08655`로 변환 (앞에 0 자동 추가)

### 사용 예시
```bash
/create-pr                       # 현재 브랜치에서 자동으로 부모 브랜치 결정 (기본값: develop)
/create-pr develop               # develop 브랜치를 base로 지정
/create-pr epic-ai/main          # epic accumulator main 을 base로 지정 (stack PR)
/create-pr GBIZ-19448            # GBIZ-19448 브랜치를 base로 하여 현재 브랜치에서 PR 생성
/create-pr 20251                 # 숫자만 입력 → GBIZ-20251 브랜치를 base로 사용
/create-pr 8655                  # 4자리 숫자 → GBIZ-08655 브랜치를 base로 사용
```

## 실행 단계

### 0단계: 빌드 체크 (check-build agent 강제 호출)

PR 생성 전 **컴파일 + 단위 테스트 검증을 check-build 에이전트에 격리 컨텍스트로 위임**. 통과 후에만 다음 단계 진행.

> **이 단계의 가치**: pre-push hook 의 `qualityGateFast` 는 **detekt 만** 돌고 컴파일/단위 테스트는 안 함 → check-build 가 PR 생성 차단 전 사전 검증. epic 누적 PR 도 강제 (CI 는 develop 진입 PR 만 트리거).

`Agent` 도구 1회 호출:
- `subagent_type`: `check-build`
- `description`: `Build verify before PR`
- `prompt`: `현재 브랜치 변경 모듈의 컴파일 + 단위 테스트를 격리 컨텍스트에서 실행. 결과를 표 형식으로 반환.`

**실패 분기**:
- 컴파일 실패: **PR 생성 중단** + 에러 원인 안내 → 사용자 fix 후 재호출
- 테스트 실패: 실패 테스트 안내 + "계속 진행할까요?" 확인 (사용자 동의 시 진행)
- 모두 통과: 다음 단계 진행

> ship Step 3 에서 호출 시에도 동일. ship 안에서 별도 check-build 호출 없음 (중복 방지).

### 1~3단계: 브랜치 정보 / GBIZ 추출 / Base 결정 (스크립트 위임)

아래 스크립트 한 번 실행으로 현재 브랜치, GBIZ 번호, base 브랜치, 원격 동기화 상태, Label 추정, 이미 열린 PR 까지 결정적으로 확인됩니다.

```bash
.claude/scripts/branch-info.sh "$ARGUMENTS"
```

- 인자 없음 → 부모 브랜치 자동 탐색 (`origin/` 데코레이션 + reflog). 실패 시 `develop` fallback
- 일반 브랜치명 (예: `develop`, `epic-ai/main`, `qa`, `main`) → 원격에 존재하면 그대로 base
- GBIZ 번호 / 숫자 (예: `20251`, `8655`, `GBIZ-19448`) → 4자리는 앞에 0 자동 추가하여 매칭 브랜치 검색
- 출력에 `### ⚠ 이미 열린 PR` 섹션이 있으면 기존 PR 안내 후 종료 (6단계 대체)

**브랜치 컨벤션 기반 참고** (스크립트 출력으로 판단):
- feature 브랜치 → `develop`
- hotfix 브랜치 → `main`
- 하위 feature 브랜치 → 상위 feature (auto-detected)

### 4단계: Notion 카드 검색
GBIZ 번호로 Notion 작업 카드 검색하여 정보 수집:
- 제목, URL
- Figma 링크, API 문서 등 참고 링크

### 5단계: PR 정보 자동 생성 및 사용자 확인
- **제목 생성**: `[GBIZ-번호] {Notion 카드 제목에서 [B2C][Android] 프리픽스 제외한 본문}` (예: 노션 `[B2C][Android] 매거진 > 콕 예약 상세 > 백키 처리` → PR `[GBIZ-XXXXX] 매거진 > 콕 예약 상세 > 백키 처리`)
- **본문 생성**: 아래 PR 본문 구조 참고
- **미리보기**: 생성된 PR 제목과 본문을 사용자에게 표시
- **수정 요청**: 사용자가 내용 수정을 요청하면 반영
- **승인 대기**: 사용자 승인 후 실제 PR 생성 진행
- **작업 사항 저장**: 승인된 작업 사항 내용을 변수에 저장 (Notion 업데이트용)

### 6단계: 기존 PR 확인
1단계 스크립트 출력의 `### ⚠ 이미 열린 PR` 섹션 참조. 있으면 링크 안내 후 종료.

### 7단계: Push 및 PR 생성

#### 7-1. Push 상태 확인 및 처리
1단계 스크립트 출력의 `### Remote Sync` 섹션 참조.
- `origin/{브랜치} 없음` → `git push -u origin {브랜치명}`
- `ahead: N, behind: 0` (N>0) → `git push`
- `behind` 가 있으면 rebase 필요 여부 확인 후 진행

#### 7-2. Label 자동 설정
1단계 스크립트 출력의 `Label 추정` 값을 사용. 없으면 label 없이 PR 생성.

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

- Notion 카드 제목에서 `[B2C][Android]` 프리픽스 제외 (notion-convention.md `[B2C][Android] {영역} > {위치} > {동작}` 형식 따름)
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

### 필수
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
- **사용자가 명시적으로 브랜치를 지정하면 무조건 해당 브랜치를 base로 사용**

### 금지
- Assignee/Reviewers 수동 설정 (GitHub에서 자동 할당됨)
- GBIZ 번호 없이 PR 생성
- Summary/Test plan 형식 사용 → 작업 사항/확인 사항 형식 사용
- **PR 본문에 Claude 서명·Co-Author·`🤖 Generated with Claude Code`·이모지 삽입 금지** 

## 에러 처리
- **GBIZ 번호 없음**: 브랜치명에서 GBIZ 패턴을 찾을 수 없는 경우 안내
- **Notion 카드 없음**: 해당 GBIZ 번호의 작업 카드가 없는 경우 기본 템플릿 사용
- **Push 실패**: 네트워크 오류 등으로 push 실패 시 재시도 안내
- **PR 생성 실패**: gh CLI 오류 시 수동 생성 방법 안내
- **브랜치 없음**: 해당 GBIZ 번호의 브랜치가 없으면 안내 메시지 표시

## 상세 문서
- 컨벤션: `.docs/conventions/pr-convention.md`

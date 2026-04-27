---
name: create-pr
description: PR 템플릿 기반 Pull Request 자동 생성. 베이스 브랜치를 인자로 받고, 나머지는 git diff에서 자동 생성.
---

# Pull Request 자동 생성

git diff와 커밋 메시지를 분석하여 프로젝트 PR 템플릿에 맞는 PR을 자동 생성합니다.

## 사용법

```bash
/create-pr develop                          # 베이스 브랜치 지정
/create-pr epic-cok                         # epic 브랜치로 지정
/create-pr develop --reviewer kiwi,marty    # 리뷰어 지정 (닉네임 가능)
/create-pr develop "리뷰 요청사항 내용"       # 리뷰 요청사항 추가
```

## 참조

- [PR 템플릿](../../../.github/pull_request_template.md)
- [팀 설정](./../config/team.json) — 리뷰어 기본값, 닉네임 매핑

## 처리 단계

### 1. 사전 확인

- **베이스 브랜치 (필수)**:
  - 사용자가 인자로 명시한 경우에만 해당 값을 사용한다
  - **사용자가 명시하지 않은 베이스 브랜치를 Claude가 임의로 추측하여 채우는 것은 절대 금지한다** (develop, main 등 자동 추측 금지)
  - **스킬 호출 시에도 동일**: 사용자가 베이스 브랜치를 말하지 않았으면, `Skill({ args: "develop" })` 처럼 args에 임의로 넣지 말고 args 없이 호출한다
  - **인자가 없으면 반드시 `AskUserQuestion` Form으로 베이스 브랜치를 선택받는다**:
    - 채팅으로 "베이스 브랜치를 알려주세요" 등 텍스트 질문 금지, 반드시 Form 선택지 사용
    - 선택지 구성 방법 (매번 동적으로 조회하여 구성):
      1. **분기 원점 브랜치 탐색**:
         - `git log --oneline --decorate` 등으로 현재 브랜치가 분기된 부모 브랜치 후보를 찾는다
         - `git branch -r --list 'origin/<후보>'`로 **remote에 실제 존재하는지 검증**한다
         - **remote에 존재하면**: 해당 브랜치를 1순위로 배치
         - **remote에 없으면** (이미 머지 후 삭제됨): `gh pr list --state merged --head <후보> --json baseRefName --jq '.[0].baseRefName'`으로 **머지된 대상 브랜치를 추적**하여 1순위로 배치 (description에 "분기 원점 `<후보>`가 머지된 브랜치"로 표시)
      2. **관련 epic 브랜치 탐색**: `git branch -r --list 'origin/epic-*'`에서 현재 브랜치명 키워드와 매칭되는 epic 브랜치를 2순위로 배치
      3. **develop**: 기본 옵션으로 3순위 배치
    - **label에 file changes 수 표시**: 각 후보 브랜치에 대해 `git diff <후보>...HEAD --stat | tail -1`로 변경 파일 수를 조회하여 label에 포함한다. 베이스 브랜치 선택 실수를 줄이기 위함.

    ```jsonc
    // AskUserQuestion 호출 템플릿 (options는 매번 동적으로 구성)
    {
      "questions": [{
        "question": "PR의 베이스 브랜치를 선택해주세요.",
        "header": "베이스 브랜치",
        "options": [
          // 최대 4개, 아래 순위에 따라 동적 구성
          // 1순위: 분기 원점 브랜치 (remote 존재 시) 또는 머지 대상 브랜치 (삭제된 경우)
          // 2순위: 브랜치명 키워드 매칭 epic 브랜치
          // 3순위: develop
          // label 형식: "브랜치명 (N files changed)"
          // 예(remote 존재): { "label": "GBIZ-26351-... (5 files)", "description": "분기 원점 브랜치" }
          // 예(머지 후 삭제): { "label": "epic-cok (5 files)", "description": "분기 원점 GBIZ-26353-...가 머지된 브랜치" }
        ],
        "multiSelect": false
      }]
    }
    ```
- **기존 PR 확인**: `gh pr list --head [현재브랜치]`로 중복 방지
  - 기존 PR이 있으면 `gh pr edit --body`로 본문 업데이트
- **리모트 동기화**: 커밋이 푸시되지 않았으면 `git push -u origin [브랜치]` 실행

### 2. 변경사항 분석

```bash
git log [base]..HEAD --oneline          # 커밋 내역
git diff [base]...HEAD --stat           # 변경 파일 통계
git diff [base]...HEAD                  # 상세 diff
```

- 커밋 메시지와 diff를 분석하여 작업 내용 자동 요약
- 변경된 파일 타입/위치를 기반으로 테스트 방법 자동 제안

### 3. PR 제목 생성

- 형식: `GBIZ-XXXXX 변경사항 요약`
- 브랜치명에서 `GBIZ-XXXXX` 패턴 자동 추출
- 커밋 메시지를 기반으로 한 줄 요약
- 70자 이내

### 4. PR 본문 작성

[PR 템플릿](../../../.github/pull_request_template.md) 형식을 따릅니다.

#### 🎯 작업 내용
- git diff와 커밋 메시지를 분석하여 **자동 생성**
- 기술적 나열이 아닌, 변경의 목적과 결과 중심으로 작성
- 글머리 기호로 핵심 변경사항 정리

#### 📋 체크리스트
- PR 템플릿의 체크리스트를 그대로 포함 (체크하지 않은 상태로)

#### 🧪 테스트 방법
- 변경된 파일 타입과 위치를 기반으로 **자동 제안**:
  - 컴포넌트/페이지 변경 → 해당 페이지 접속 및 동작 확인 단계
  - API/훅 변경 → 관련 기능 호출 확인 단계
  - 유틸/설정 변경 → 빌드/테스트 실행 확인 단계
  - 문서 변경 → 문서 내용 확인

#### 📸 스크린샷
- UI 변경 파일(*.tsx) 포함 여부 자동 판단
  - 포함: "UI 변경사항이 있습니다. 스크린샷을 첨부해주세요." 안내
  - 미포함: "해당 없음"

#### 💭 리뷰 요청사항
- 사용자가 인자로 전달한 경우 해당 내용 삽입
- 전달하지 않은 경우 비워둠

### 5. PR 생성 및 설정

```bash
# PR 생성
gh pr create --base [베이스] --title "[제목]" --body "[본문]"

# 어사이니 설정 (git user 기반 자동 감지)
gh pr edit [PR번호] --add-assignee @me

# 리뷰어 설정
gh pr edit [PR번호] --add-reviewer [리뷰어1],[리뷰어2]
```

### 6. 결과 보고

- 생성된 PR URL 표시
- 리뷰어, 어사이니 설정 결과 표시

## 리뷰어 설정 규칙

1. `--reviewer` 인자가 있으면 해당 리뷰어 사용
2. 인자가 없으면 `.claude/config/team.json`의 `reviewers.default` 사용
3. 닉네임은 `reviewers.nicknames`에서 GitHub 유저네임으로 변환

```bash
# 닉네임으로 지정
/create-pr develop --reviewer kiwi,marty
# → kiwi-herren, marty404 로 변환

# GitHub 유저네임 직접 지정도 가능
/create-pr develop --reviewer kiwi-herren,marty404
```

## 기존 PR 업데이트

같은 브랜치에 이미 PR이 있으면 새로 생성하지 않고 본문을 업데이트합니다.

```bash
# 기존 PR 감지
gh pr list --head [현재브랜치] --json number,url

# 본문 업데이트
gh pr edit [PR번호] --body "[새 본문]"
```

## 주의사항

- 베이스 브랜치는 반드시 지정해야 함 (자동 추측 안 함)
- PR 생성 전 모든 변경사항이 커밋되어 있어야 함 (uncommitted 변경이 있으면 경고)
- 체크리스트는 체크하지 않은 상태로 생성 (리뷰어가 확인)
- 본문 생성 후 사용자에게 확인 요청 없이 바로 생성 (최소 대화형)

---
name: instaget-front-create-pr
description: 인스타겟 프론트엔드 PR 템플릿 기반 Pull Request 자동 생성. 리뷰어/담당자 자동 할당 및 노션 백로그 연동.
---

# Pull Request 자동 생성 (인스타겟 웹)

git diff와 커밋 메시지를 분석하여 인스타겟 프론트엔드 PR 템플릿에 맞는 PR을 자동 생성합니다.

## 사용법

```bash
/instaget-front-create-pr                     # 베이스 브랜치 미지정 (사용자에게 물어봄)
/instaget-front-create-pr develop             # 베이스 브랜치 지정
/instaget-front-create-pr epic-overseas       # epic 브랜치로 지정
```

## 처리 단계

### 1. 사전 확인

- **현재 브랜치 확인**: `git branch --show-current`로 IQLX-XXXX 티켓 번호 추출
- **베이스 브랜치 (필수)**:
  - 사용자가 인자로 명시한 경우에만 해당 값을 사용한다
  - **사용자가 명시하지 않은 베이스 브랜치를 Claude가 임의로 추측하여 채우는 것은 절대 금지한다**
  - **인자가 없으면 반드시 `AskUserQuestion` Form으로 베이스 브랜치를 선택받는다**:
    - 채팅으로 "베이스 브랜치를 알려주세요" 등 텍스트 질문 금지, 반드시 Form 선택지 사용
    - 선택지 구성 방법 (매번 동적으로 조회하여 구성):
      1. **분기 원점 브랜치 탐색**: `git log --oneline --decorate` 등으로 부모 브랜치 후보 탐색, remote 존재 여부 검증
      2. **관련 epic 브랜치 탐색**: `git branch -r --list 'origin/epic-*'`에서 현재 브랜치명 키워드 매칭
      3. **develop**: 기본 옵션으로 배치

    ```jsonc
    {
      "questions": [{
        "question": "PR의 베이스 브랜치를 선택해주세요.",
        "header": "베이스 브랜치",
        "options": [
          // 동적 구성, label에 file changes 수 표시
          // 예: { "label": "develop (12 files)", "description": "기본 개발 브랜치" }
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

- 형식: `<type>(IQLX-XXXX): <간단한 설명>`
- 가장 많이 사용된 커밋 타입을 PR 타입으로 선택
- 커밋 메시지를 기반으로 한 줄 요약 (한글)
- 70자 이내

예시:
```
feat(IQLX-7201): GTM 클릭 이벤트 트래킹 추가
refactor(IQLX-7146): i18n 빌드타임 번역 스크립트 개선
```

### 4. PR 본문 작성

```markdown
## Summary
- 변경사항 요약 (1-3 bullet points)

## Changes
- 구체적인 변경 내용 (모듈/기능별로 그룹핑)

## Test Coverage
- 테스트 커버리지 정보 (해당 시)

## Test Plan
- [ ] 테스트 체크리스트 항목 1
- [ ] 테스트 체크리스트 항목 2

## Commits
- 포함된 커밋 목록

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

#### 작성 규칙
- Summary: 변경의 목적과 결과 중심
- Changes: 기술적 나열이 아닌 기능 레벨 설명
- Test Plan: 변경된 파일 타입에 따라 자동 제안
  - 컴포넌트/페이지 변경 → 해당 페이지 동작 확인
  - API/훅 변경 → 관련 기능 호출 확인
  - 유틸/설정 변경 → 빌드/테스트 실행 확인
- 대화 중 공유된 피그마 링크가 있으면 PR 본문에 포함

### 5. PR 생성 및 설정

```bash
# PR 생성
gh pr create \
  --repo herren-official/instaget-b2c-frontend \
  --base [베이스] \
  --title "[제목]" \
  --body "$(cat <<'EOF'
[본문]
EOF
)"

# 리뷰어 설정: marty404
gh pr edit [PR번호] --add-reviewer marty404

# 담당자 설정: charlie12-21
gh pr edit [PR번호] --add-assignee charlie12-21
```

### 6. 노션 백로그 업데이트

PR 생성 후 자동으로 노션 백로그도 업데이트한다:

1. IQLX-XXXX로 노션 검색 (`notion-search`)
2. 백로그 페이지 fetch (`notion-fetch`)
3. PR Summary/Changes 내용과 동일하게 백로그의 작업내용 섹션 업데이트 (`notion-update-page`)
4. Todo 항목도 함께 체크/작성

### 7. 결과 보고

- 생성된 PR URL 표시
- 리뷰어(marty404), 담당자(charlie12-21) 설정 결과 표시
- 노션 백로그 업데이트 결과 표시

## 기존 PR 업데이트

같은 브랜치에 이미 PR이 있으면 새로 생성하지 않고 본문을 업데이트합니다.

```bash
gh pr list --head [현재브랜치] --json number,url
gh pr edit [PR번호] --body "[새 본문]"
```

## 주의사항

- 베이스 브랜치는 사용자 확인 필수 (자동 추측 안 함)
- PR 생성 전 모든 변경사항이 커밋되어 있어야 함
- 본문 생성 후 사용자에게 확인 요청 없이 바로 생성 (최소 대화형)
- **리뷰어**: marty404 고정
- **담당자**: charlie12-21 고정
- 사용자가 공유한 스크린샷은 PR에 넣지 않음 (잘못된 화면인 경우가 많음)

---
name: b2b-web-create-pr
description: "GitLab Flow 기반 PR 생성 자동화 (대화형 템플릿)"
argument-hint: "[base-branch] [head-branch]"
allowed-tools: ["bash", "read", "write", "edit", "multi_edit", "grep", "glob", "ls"]
---

# Pull Request 생성

## 개요
프로젝트의 PR 템플릿을 기반으로 대화형으로 PR을 생성합니다.

## 처리 단계

### 자동 기능
- **작업 내용 생성**: git diff와 커밋 메시지를 분석하여 변경사항을 요약
- **테스트 방법 생성**: 변경된 파일의 타입과 위치를 분석하여 적절한 테스트 단계 제안

1. **브랜치 정보 확인**
   - base branch와 head branch 확인
   - 현재 브랜치 상태 확인
   - 커밋 내역 확인
   - 변경된 파일 목록 및 diff 분석

2. **PR 제목 생성**
   - 형식: `GBIZ-XXXX 변경사항 요약`
   - 브랜치명에서 GBIZ-ID 추출
   - 주요 변경사항을 한 줄로 요약

3. **PR 내용 작성 (대화형)**
   각 섹션별로 순서대로 질문하여 템플릿 작성:
   
   a. **리뷰 요청사항**: "특별히 리뷰받고 싶은 부분이 있나요?"

4. **체크리스트 확인**
   
   a. **Lint/Type 체크**
      - git status로 unstaged/untracked 파일 확인
      - 모든 변경사항이 커밋된 경우: "✅ Lint/Type 체크 통과 (이미 커밋됨)"
      - 커밋되지 않은 변경사항이 있는 경우: "❌ Lint/Type 체크 실패. 수정 후 다시 실행해주세요"
   
   b. **대화형 확인 항목**
      - "코드 리뷰 요청 전 self-review를 완료하셨습니까? (y/n)"
      - "로컬에서 정상 동작을 확인하셨습니까? (y/n)"
      - "영향받는 기능들을 테스트하셨습니까? (y/n)"
      - "문서 업데이트가 필요한 경우, 업데이트하셨습니까? (y/n)"

5. **스크린샷 캡쳐 (UI 변경사항이 있는 경우)**
   - UI 변경이 포함된 PR인지 자동 판단 (변경된 파일이 `*.tsx`, `*.styles.ts` 등을 포함하는 경우)
   - UI 변경이 있는 경우 사용자에게 질문: "UI 변경사항 스크린샷을 캡쳐할까요? (y/n)"
   - 'y' 선택 시:
     a. 로컬 dev 서버(port 3000) 실행 여부 확인, 미실행 시 `yarn dev`로 시작
     b. 변경된 파일의 페이지 경로를 분석하여 영향받는 페이지 목록 추출
        - `src/pages/` 하위 변경 → 해당 페이지 URL 추출
        - `src/components/` 하위 변경 → 해당 컴포넌트를 사용하는 페이지 추적
        - 여러 페이지가 영향받으면 **모든 관련 페이지**의 스크린샷을 캡쳐
     c. 사용자에게 캡쳐할 페이지 목록 확인 및 모달/버튼 클릭 등 인터랙션 여부 질문
     d. 응답을 바탕으로 Playwright 스크린샷 스크립트를 `scripts/` 하위에 임시 생성
        - 범용 스크립트(`scripts/screenshot.mjs`)가 있으면 그것을 활용
        - 모달 등 인터랙션이 필요하면 별도 임시 스크립트 생성 (예: `scripts/screenshot-temp-pr.mjs`)
     e. before 스크린샷: `git stash`로 변경사항 임시 저장 → HMR 반영 대기 → 각 페이지 캡쳐 → `git stash pop`
     f. after 스크린샷: HMR 반영 대기 → 각 페이지 캡쳐
     g. 캡쳐된 이미지를 GitHub Draft Release(`screenshots-temp`)에 asset으로 업로드
        ```bash
        # 파일명을 PR번호-이름.png 형식으로 업로드 (중복 방지)
        gh release upload screenshots-temp <파일> --clobber
        # URL 추출
        gh release view screenshots-temp --json assets --jq '.assets[] | select(.name == "<파일명>") | .url'
        ```
     h. PR body의 스크린샷 섹션에 **페이지별로** before/after 이미지 URL 삽입
     i. **정리**: 임시 생성한 스크린샷 스크립트 파일 삭제, `screenshots/` 디렉토리 삭제
     j. **오래된 asset 정리**: 30일 이상 된 asset을 자동 삭제
        ```bash
        gh release view screenshots-temp --json assets \
          --jq '[.assets[] | select(.createdAt < "'$(date -v-30d +%Y-%m-%d)'")]' \
          | jq -r '.[].name' \
          | xargs -I{} gh release delete-asset screenshots-temp {} -y
        ```
   - 'n' 선택 시: 기존처럼 수동 안내 텍스트 삽입

6. **PR 생성 및 설정**
   - 먼저 `gh pr list --head [현재브랜치]`로 기존 PR 존재 여부 확인
   - **기존 PR이 없는 경우**: `gh pr create`로 새 PR 생성
     - GitHub CLI 미설치 시: 브랜치 푸시 후 URL 안내
   - **기존 PR이 있는 경우**: `gh pr edit --body`로 PR 본문 업데이트
     - 커밋 내역, 스크린샷 등 변경된 내용을 반영하여 body 전체를 재생성
   - PR 생성/업데이트 후 추가 설정:
     - Assignee: PR 작성자(`@me`)로 자동 지정
     - Reviewer 선택 (대화형):
       - "리뷰어를 지정하시겠습니까? (tim060/kiwi-herren/jikor1st/다른 GitHub ID/n으로 건너뛰기)"
       - 사용자가 선택하거나 직접 입력
       - 'n' 입력 시 리뷰어 없이 진행
   - 추가 리뷰어나 라벨은 생성 후 GitHub에서도 설정 가능

## PR 템플릿 형식

```markdown
## 🎯 작업 내용

{사용자 입력}

## 📋 체크리스트

- [ ] 코드 리뷰 요청 전 self-review 완료
- [ ] 로컬에서 정상 동작 확인
- [ ] 영향받는 기능들 테스트 완료
- [ ] Lint/Type 체크 통과 (`yarn lint`)
- [ ] 필요한 경우 문서 업데이트 완료

## 🧪 테스트 방법

{사용자 입력}

## 📸 스크린샷

{UI 변경사항이 있는 경우 자동 캡쳐된 before/after 이미지, 없으면 "해당 없음"}

## 💭 리뷰 요청사항

{사용자 입력 또는 빈 값}
```

## 사용 예시

```bash
# 현재 브랜치에서 develop으로 PR 생성
/create-pr develop

# 특정 브랜치에서 deploy-153으로 PR 생성
/create-pr deploy-153 GBIZ-1234-add-feature
```

## 브랜치별 머지 규칙

| Source | Target | 머지 방법 |
|--------|--------|----------|
| sub-feature | feature | Squash and merge |
| feature | deploy-ID | Create a merge commit |
| deploy-ID | develop | Create a merge commit |
| develop | main | Create a merge commit |

## GitHub CLI 설치 방법

```bash
# macOS
brew install gh

# 인증
gh auth login
```

## 주의사항

1. **PR 생성 전 확인**
   - 모든 테스트 통과
   - 린트 규칙 준수
   - 커밋 메시지 컨벤션 준수

2. **리뷰어 지정**
   - 1명이라도 approve 시 merge 가능
   - PR 작성자는 자동으로 assignee로 지정됨

3. **작은 단위 PR**
   - 한 PR이 너무 많은 변경 포함 금지
   - 기능 단위로 분리하여 제출

4. **템플릿 작성**
   - 각 섹션을 충실히 작성
   - 스크린샷/GIF 적극 활용
   - 관련 백로그 링크 포함
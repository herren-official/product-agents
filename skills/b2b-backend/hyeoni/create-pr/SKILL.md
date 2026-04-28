---
name: b2b-backend-create-pr
description: 현재 브랜치 변경사항을 분석하여 PR Convention에 맞는 Pull Request를 자동 생성한다. [CRM][GBIZ-번호] 제목 + 표준 본문 템플릿.
---

# Pull Request 자동 생성 커맨드

이 커맨드는 현재 브랜치의 GBIZ 번호와 커밋 내역을 분석하여 PR Convention에 맞는 Pull Request를 자동으로 생성합니다.

## 사용 방법

### 명령어 형식
```
/b2b-backend-create-pr
/b2b-backend-create-pr {타겟 브랜치} 로 타겟 브랜치 설정해줘
```

### 전제 조건
1. 현재 브랜치명이 `GBIZ-번호-description` 형식이어야 함
2. 커밋이 모두 완료된 상태여야 함
3. GitHub CLI (`gh`)가 설치되어 있어야 함

## PR 제목 형식

```
[CRM][GBIZ-번호] 제목
```

- `[CRM]` 태그는 필수로 앞에 붙임
- GBIZ 번호를 대괄호로 묶어 표시
- 제목은 브랜치명의 description 부분을 한국어로 의역하여 사용

## PR 본문 구조

```markdown
## 개요
- 변경사항의 목적과 배경을 간략히 기재

## 작업사항
- 구체적인 작업 내용을 나열
  <br>

## 변경로직

### 변경전


### 변경후


## 사용방법


## 기타


## 참고
* [GBIZ-번호](https://www.notion.so/GBIZ-번호)
```

## 실행 순서

### 1단계: 현재 브랜치 확인 및 검증
```bash
git branch --show-current
```

- 브랜치명이 `GBIZ-{번호}-{description}` 형식인지 확인
- develop/main 브랜치가 아닌지 확인
- GBIZ 번호 추출

### 2단계: 커밋 상태 확인
```bash
git status --short
```

- 커밋되지 않은 변경사항이 있으면 경고 후 중단

### 3단계: 리모트 브랜치 확인 및 push
```bash
git rev-parse --abbrev-ref --symbolic-full-name @{u}
```

- upstream이 없으면 `git push -u origin {브랜치명}` 자동 실행
- 로컬과 리모트가 동기화되어 있는지 확인 후 필요시 push

### 4단계: 커밋 내역 및 변경 파일 분석
```bash
# 타겟 브랜치 대비 커밋 목록
git log {타겟브랜치}..HEAD --oneline

# 변경된 파일 목록
git diff {타겟브랜치}...HEAD --name-only
```

- 커밋 메시지를 기반으로 작업사항 자동 생성
- 변경 파일 패턴으로 개요 보완

### 5단계: PR 제목 및 본문 생성

**PR 제목 생성**:
- 브랜치명 description 부분을 한국어로 의역
- 형식: `[CRM][GBIZ-{번호}] {제목}`

**PR 본문 생성**:
- 커밋 메시지에서 작업사항 추출
- 변경 파일 분석으로 개요 작성
- 변경로직/사용방법/기타 섹션은 빈 상태로 제공 (사용자가 필요 시 작성)
- 참고 섹션에 GBIZ 번호 링크 자동 추가

### 6단계: PR 생성
```bash
gh pr create \
  --title "[CRM][GBIZ-번호] 제목" \
  --body "..." \
  --base {타겟브랜치} \
  --assignee herren-hyeoni
```

**자동 설정**:
- `--base develop`: 기본 타겟 브랜치 (인자로 변경 가능)
- `--assignee herren-hyeoni`: 작업자 본인으로 설정

## 에러 처리

### 브랜치명 형식 오류
```
오류: 브랜치명이 올바른 형식이 아닙니다.
현재 브랜치: feature/add-booking-api
필요 형식: GBIZ-{번호}-{description}
```

### 커밋되지 않은 변경사항
```
경고: 커밋되지 않은 변경사항이 있습니다.
먼저 커밋을 완료한 후 PR을 생성하세요.
```

### GitHub CLI 미설치
```
오류: GitHub CLI (gh)가 설치되어 있지 않습니다.
설치 방법: brew install gh
```

### PR이 이미 존재하는 경우
```
경고: 이 브랜치의 PR이 이미 존재합니다.
기존 PR: #{번호}
URL: https://github.com/...
```

## 주의사항

1. **브랜치명 규칙 준수**: 반드시 `GBIZ-{번호}-{description}` 형식 사용
2. **커밋 완료 필수**: PR 생성 전 모든 변경사항을 커밋해야 함
3. **타겟 브랜치 확인**: 기본값은 `develop`, 다른 브랜치 지정 시 인자로 전달
4. **PR 본문 보완**: 자동 생성된 본문의 변경로직/사용방법/기타 섹션은 필요 시 GitHub UI에서 직접 작성

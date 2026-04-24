---
name: b2c-ios-plan
description: "노션 일감 URL을 분석하여 작업 계획을 자동 수립하고 노션 문서를 업데이트합니다"
argument-hint: "<노션 일감 URL>"
disable-model-invocation: false
allowed-tools: ["Bash", "Read", "Grep", "Glob", "mcp__notionMCP__notion-fetch", "mcp__notionMCP__notion-update-page", "mcp__notionMCP__notion-search"]
---

# /plan - 노션 일감 작업 계획 자동 수립

## 실행 알림
이 스킬이 실행되면 가장 먼저 "[plan] 스킬이 실행되었습니다."를 출력할 것

$ARGUMENTS

## 참조 스킬

이 스킬은 다음 서브 스킬의 프로세스를 조합합니다:

| 스킬 | 역할 | 해당 단계 |
|------|------|----------|
| `notion-read` | 노션 일감 읽기 및 파싱 | 1단계 |
| `branch-strategy` | 브랜치 전략 수립 | 3단계 |
| `notion-update` | 노션 페이지 업데이트 | 6단계 |

> 각 스킬의 상세 프로세스는 해당 스킬 문서 참조

## 0. 현재 상태 (동적 주입)

### 현재 브랜치
!`git branch --show-current`

### GBIZ 번호
!`git branch --show-current | grep -oE "GBIZ-[0-9]+" | head -1 || echo "GBIZ 번호 없음"`

### 관련 브랜치 목록
!`git branch -a --sort=-committerdate | head -20`

## 실행 프로세스

### 1단계: 노션 일감 분석

> `notion-read` 스킬의 프로세스를 따른다

- notionMCP의 notion-fetch 도구로 페이지 정보 가져오기
- GBIZ 번호 확인 (`userDefined:ID` 프로퍼티)
- 작업 내용 상세 파악
  - 작업 설명 및 요구사항
  - 첨부된 Figma 링크 분석
  - 참고 자료 및 스펙 문서 확인
- 작업 유형 판단 (Feature, UI Test, Bug Fix 등)

### 2단계: 코드베이스 분석
- 연관 파일 분석
  - 수정해야 할 파일
  - 참고할 유사 구현 (3개 이상)
  - 테스트 패턴
- 프로젝트 컨벤션 확인

> Git 명령어는 [BRANCH_CONVENTION.md](.docs/BRANCH_CONVENTION.md)의 "유용한 Git 명령어" 섹션 참조

### 3단계: Git 전략 수립

> `branch-strategy` 스킬의 프로세스를 따른다 (베이스 브랜치, 브랜치명, PR 타겟 결정)

### 4단계: 작업 계획 상세화
- [NOTION_TASK_PLANNING.md](.docs/NOTION_TASK_PLANNING.md) 템플릿 참고
- 수정 파일 목록 작성
- 테스트 시나리오 설계 (테스트 작업인 경우)
- 단계별 작업 계획

### 5단계: 사용자 확인

아래 출력 형식으로 계획을 보여준 후 확인 요청:

```
작업 계획을 수립했습니다.

[출력 형식에 따른 계획 내용]

[Y] 노션 업데이트 진행 / [N] 취소 / [E] 계획 수정
```

### 6단계: 노션 문서 업데이트

> `notion-update` 스킬의 프로세스를 따른다

- 사용자 승인 후 노션 페이지에 작업 계획 업데이트
- [NOTION_TASK_GUIDE.md](.docs/NOTION_TASK_GUIDE.md) 참고하여 형식 결정
- Git 정보 기록, 체크리스트 생성

## 출력 형식

```markdown
## [GBIZ-XXXXX] {작업명} - 작업 계획

### 1. 작업 개요
- **목적**: {작업 목적}
- **유형**: {Feature/UI Test/Bug Fix/etc}
- **참고 자료**:
  - Figma: {첨부된 Figma 링크}
  - 스펙: {관련 스펙 문서}

### 2. Git 전략
- **현재 브랜치**: {current-branch}
- **새 브랜치**: `{Prefix}/GBIZ-XXXXX-{description}`
- **베이스 브랜치**: {base-branch}
- **PR 타겟**: {target-branch}

### 3. 커밋 전략
- 예상 커밋 개수: X개
- 논리적 단위로 분리

### 4. 작업 범위
#### 수정 파일
- [ ] {File1.swift} - {수정 내용}
- [ ] {File2.swift} - {수정 내용}

#### 테스트 시나리오 (테스트 작업의 경우)
1. **{테스트명}**
   - Given: {전제 조건}
   - When: {동작}
   - Then: {기대 결과}

### 5. 작업 단계
**Phase 1: 준비**
- [ ] 브랜치 생성
- [ ] 프로젝트 빌드 확인 (`tuist generate --no-open`)

**Phase 2: 구현**
- [ ] {구현 내용 1}
- [ ] {구현 내용 2}

**Phase 3: 검증**
- [ ] 전체 테스트 실행
- [ ] 빌드 확인
- [ ] 테스트 로그 정리 (`rm -f *_test_output.log`)

**Phase 4: PR**
- [ ] 커밋 & 푸시
- [ ] PR 생성

### 6. 주의사항
- {특별 주의사항}
- {제약사항}
```

## 에러 처리

| 에러 | 대응 |
|------|------|
| 노션 접근 실패 | 권한/URL 확인 요청 |
| GBIZ 번호 없음 | 수동 입력 요청 |
| 관련 브랜치 없음 | 현재 브랜치 또는 develop을 베이스로 사용 |

## 작업 복잡도 분류 기준

작업 계획 수립 시 복잡도를 기준으로 단계를 조정한다:

| 복잡도 | 기준 | 특징 |
|--------|------|------|
| Simple | 단일 파일 수정, 기존 패턴 그대로 적용 | 참고 구현 1개로 충분, 테스트 케이스 단순 |
| Medium | 2-4개 레이어 수정, 일부 신규 로직 | 참고 구현 3개 이상 필요, 테스트 케이스 다수 |
| Complex | 신규 Feature/모듈, 여러 레이어 동시 변경 | 설계 검토 필요, 단계별 커밋 계획 필수 |

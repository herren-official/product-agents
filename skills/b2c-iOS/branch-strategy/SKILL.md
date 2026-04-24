---
name: b2c-ios-branch-strategy
description: "현재 브랜치 상태를 분석하고 베이스 브랜치, 새 브랜치명, PR 타겟을 결정합니다"
argument-hint: "[GBIZ 번호 또는 작업 설명]"
disable-model-invocation: false
allowed-tools: ["Bash", "Read"]
---

# /branch-strategy - Git 브랜치 전략 수립

## 실행 알림
이 스킬이 실행되면 가장 먼저 "[branch-strategy] 스킬이 실행되었습니다."를 출력할 것

$ARGUMENTS

## 0. 현재 상태 (동적 주입)

### 현재 브랜치
!`git branch --show-current`

### GBIZ 번호
!`git branch --show-current | grep -oE "GBIZ-[0-9]+" | head -1 || echo "GBIZ 번호 없음"`

### 관련 브랜치 목록 (최근순)
!`git branch -a --sort=-committerdate | head -20`

### 분기 원본 감지
!`CURRENT=$(git branch --show-current) && CREATED_FROM=$(git reflog show "$CURRENT" 2>/dev/null | grep "branch: Created from" | head -1 | sed 's/.*Created from //') && echo "분기 원본: $CREATED_FROM" && echo "develop 머지베이스: $(git merge-base HEAD origin/develop 2>/dev/null || echo 'N/A')" || echo "감지 실패"`

## 실행 프로세스

> 상세 규칙은 [BRANCH_CONVENTION.md](.docs/BRANCH_CONVENTION.md) 참조

### 1단계: 현재 상태 분석
- 동적 주입된 현재 브랜치, 관련 브랜치, 분기 원본 확인
- 입력된 GBIZ 번호 또는 작업 설명 확인

### 2단계: 베이스 브랜치 결정

**우선순위:**

| 순위 | 조건 | 베이스 |
|------|------|--------|
| 1 | 사용자가 명시적으로 지정 | 지시된 브랜치 |
| 2 | 현재 브랜치에서 분기 (기본) | 현재 브랜치 |
| 3 | 같은 Prefix의 최신 브랜치 | 해당 브랜치 |
| 4 | 독립 작업 (최후 수단) | develop |

**핵심 원칙:**
- 절대로 무조건 develop을 베이스로 설정하지 않음
- 관련 작업 브랜치가 있으면 해당 브랜치에서 분기

### 3단계: Prefix 결정

노션 일감 정보 또는 사용자 입력을 기반으로 결정:

1. **에픽/마일스톤 확인** - 노션 프로퍼티에서 기능 영역 파악
2. **기존 브랜치 패턴 확인** - 동일 기능의 기존 브랜치와 같은 Prefix 사용
3. **독립 작업** - Prefix 없이 `GBIZ-번호-설명` 형식

> Prefix 목록 및 선택 가이드: [BRANCH_CONVENTION.md](.docs/BRANCH_CONVENTION.md) "Prefix 선택 가이드" 참조

### 4단계: 브랜치명 생성

**형식:** `{Prefix}/GBIZ-{번호}-{케밥케이스-설명}` 또는 `GBIZ-{번호}-{케밥케이스-설명}`

**규칙:**
- 영어 + 하이픈만 사용 (한글/특수문자 금지)
- 50자 이내
- 핵심 키워드만 포함

### 5단계: PR 타겟 결정

| 작업 유형 | PR 타겟 |
|----------|---------|
| 순차 작업 (같은 Prefix) | 이전 작업 브랜치 |
| 에픽 하위 작업 | 에픽 브랜치 (`{Prefix}/GBIZ-EPIC`) |
| 독립 작업 | develop |

## 출력 형식

```markdown
### Git 브랜치 전략

| 항목 | 값 |
|------|-----|
| 현재 브랜치 | {current-branch} |
| 베이스 브랜치 | {base-branch} |
| 새 브랜치 | `{Prefix}/GBIZ-XXXXX-{description}` |
| PR 타겟 | {target-branch} |
| 선택 근거 | {우선순위 N에 따른 이유} |
```

## 에러 처리

| 에러 | 대응 |
|------|------|
| GBIZ 번호 없음 | 사용자에게 수동 입력 요청 |
| 관련 브랜치 없음 | 현재 브랜치 또는 develop을 베이스로 사용 |
| 분기 원본 감지 실패 | 사용자에게 베이스 브랜치 확인 요청 |

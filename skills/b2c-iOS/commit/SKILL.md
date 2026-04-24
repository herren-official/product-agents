---
name: b2c-ios-commit
description: "Git 커밋을 수행합니다. 변경사항을 분석하고 적절한 커밋 메시지를 생성합니다"
argument-hint: "[커밋 메시지 또는 작업 설명]"
disable-model-invocation: false
allowed-tools: ["Bash", "Read", "Grep", "Glob"]
---

# Git 커밋 자동화

## 실행 알림
이 스킬이 실행되면 가장 먼저 "[commit] 스킬이 실행되었습니다."를 출력할 것

$ARGUMENTS

## 0. 현재 상태 (동적 주입)

### 현재 브랜치
!`git branch --show-current`

### GBIZ 번호
!`git branch --show-current | grep -oE "GBIZ-[0-9]+" | head -1 || echo "GBIZ 번호 없음"`

### 변경사항 요약
!`git status --porcelain`

### Staged 변경사항
!`git diff --staged`

### Unstaged 변경사항
!`git diff`

### 최근 커밋 (메시지 스타일 참고)
!`git log --oneline -5`

## 실행 프로세스

### 1단계: Pre-Commit 검사

`/pre-commit-checker` 스킬을 Skill 도구로 실행하여 컨벤션 검사 수행.
(변경 파일이 모두 문서(.md)인 경우 이 단계 생략 가능)

- 에러가 있으면: 수정 요청 또는 사용자 확인 후 진행
- 에러가 없으면: 다음 단계로

### 2단계: 변경사항 분석

위 동적 주입 결과를 분석:
- 변경된 파일 목록 확인
- Staged/Unstaged 구분
- GBIZ 번호 확인

### 3단계: 커밋 분리 검토

- **논리적 단위 확인**: 여러 다른 작업이 섞여있으면 분리 제안
- **레이어별 분석**: Model, Repository, Feature, View, Test, Doc 분리 검토
- **파일별 작업 내용**: 같은 파일이라도 작업 내용이 다르면 분리 제안

분리가 필요한 경우:
```
변경사항이 여러 기능에 걸쳐 있습니다.
다음과 같이 커밋을 분리하시겠습니까?

1. feat: 모델 구조 추가 (Models/*.swift)
2. feat: UI 구현 (Views/*.swift)
3. test: 테스트 코드 추가 (Tests/*.swift)
```

### 4단계: 커밋 타입 결정

> [COMMIT_CONVENTION.md](.docs/COMMIT_CONVENTION.md)의 "Type (타입)" 섹션 참조
> Read 도구로 해당 문서를 읽어 올바른 커밋 타입 결정

### 5단계: 커밋 메시지 작성 및 자가 검증

**형식:**
```
<type>: <제목>

변경사항 설명

GBIZ-{번호}
```

**규칙:**
- 제목: 50자 이내, 한글, 명사형 종결
- 본문: 변경사항 설명 + GBIZ 번호 (마지막 줄)
- 구체적 표현 필수, 포괄적/추상적 표현 금지

**자가 검증:** 작성한 커밋 메시지가 다음을 위반하지 않는지 확인:
- Co-Authored-By 포함 여부 → 절대 금지
- 이모지 포함 여부 → 절대 금지
- 제목 50자 초과 여부
- GBIZ 번호 누락 여부
- 명사형 종결 여부

위반 시 자동 수정 후 다음 단계로 진행

### 6단계: 사용자 확인

```
다음과 같이 커밋하시겠습니까?

커밋 메시지:
<type>: <제목>

<본문>

GBIZ-XXXXX

변경 파일:
- path/to/File.swift (수정)
- path/to/NewFile.swift (추가)

[Y] 커밋 / [N] 취소 / [E] 메시지 수정
```

### 7단계: 커밋 실행

```bash
# 관련 파일만 선택적으로 스테이징 (git add . 사용 금지)
git add <specific-file-path>

# 커밋 메시지는 반드시 HEREDOC 형식으로 작성
git commit -m "$(cat <<'EOF'
type: 구체적인 설명

변경사항에 대한 설명

GBIZ-번호
EOF
)"
```

## 커밋 분리 예시

### Mock/테스트 분리
```bash
# 1. Mock 파일 먼저 커밋
git add Tests/Common/MockDelegate.swift
git commit -m "$(cat <<'EOF'
test: RouterTests용 MockDelegate 추가

GBIZ-19840
EOF
)"

# 2. 테스트 파일 커밋
git add Tests/ShopV2RouterTests.swift
git commit -m "$(cat <<'EOF'
test: ShopV2Router 테스트 코드 추가

GBIZ-19840
EOF
)"
```

### 문서 커밋
```bash
git add .docs/conventions/CONVENTIONS.md
git commit -m "$(cat <<'EOF'
docs: CONVENTIONS 주석 규칙 예시 간소화

반복되는 예시를 통합 정리

GBIZ-24443
EOF
)"
```

## 에러 처리

| 에러 | 대응 |
|------|------|
| pre-commit-checker 위반 | 위반 항목 수정 후 재검사 |
| GBIZ 번호 없음 | 브랜치명에서 추출 실패 시 사용자에게 수동 입력 요청 |
| 커밋 실패 | 에러 메시지 확인 후 사용자에게 보고 |
| 변경사항 없음 | "커밋할 변경사항이 없습니다" 안내 |

## 금지 사항

- `git add .` 또는 `git add -A` 사용 금지 (선택적 추가만)
- Co-Authored-By 절대 금지
- 커밋 메시지에 이모지 사용 금지
- 빌드 실패하는 코드 커밋 금지
- 포괄적/추상적 커밋 메시지 금지

## 주의사항
- 빌드가 실패하는 코드는 커밋하지 않음
- 각 커밋은 독립적으로 빌드 가능해야 함
- 너무 큰 변경사항은 논리적 단위로 분리
- GBIZ 번호는 동적 주입 결과에서 자동 확인

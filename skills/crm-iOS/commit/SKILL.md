---
name: crm-ios-commit
description: Git 커밋을 생성합니다. 커밋 전 컨벤션 검사를 수행하고, 변경사항을 분석하여 컨벤션에 맞는 커밋 메시지를 생성합니다. 커밋, crm-ios-commit, 커밋해줘 요청 시 사용.
allowed-tools: Read, Grep, Glob, Bash
---

# Commit

Git 커밋을 생성하는 스킬입니다.

## 실행 알림
이 스킬이 실행되면 가장 먼저 "[crm-ios-commit] 스킬이 실행되었습니다."를 출력할 것

## 실행 프로세스

### 1단계: Pre-Commit 검사

crm-ios-pre-commit-checker 스킬을 먼저 실행하여 컨벤션 검사 수행

- 🚨 에러가 있으면: 수정 요청 또는 사용자 확인 후 진행
- ✅ 에러가 없으면: 다음 단계로

### 2단계: 변경사항 분석

```bash
# staged 변경사항 확인
git diff --cached --stat
git diff --cached

# unstaged 변경사항도 확인
git status
```

### 3단계: GBIZ 번호 추출

현재 브랜치에서 GBIZ 번호 자동 추출:

```bash
git branch --show-current
# 예: NaverPay/GBIZ-12345-Payment-View → GBIZ-12345
# 예: GBIZ-19847-Fix-Error → GBIZ-19847
```

### 4단계: 커밋 타입 결정

| 타입 | 설명 |
|------|------|
| `feat` | 새로운 기능 |
| `fix` | 버그 수정 및 기존 로직 수정/개선 (코드 동작에 영향을 주는 변경) |
| `mod` | 코드 동작과 무관한 수정 (버튼 텍스트 변경, 주석 변경 등) |
| `doc` | 문서 생성/수정/삭제 (.md, .docs/, 스킬 문서 등) |
| `project` | 설정 변경 (plist, project setting 등) |
| `style` | 코드 스타일 수정 (공백, 줄바꿈 등) |
| `refactor` | 코드 리팩토링 |
| `perf` | 성능 향상 목적 |
| `test` | 테스트 코드 관련 |
| `revert` | 이전 커밋 revert |
| `review` | 코드리뷰 반영 사항 |

### 5단계: 커밋 메시지 작성

#### 형식
```
<type>: <제목>

GBIZ-{번호}
```

#### 규칙
- **제목**: 50자 이내 (초과 시 줄여서 작성)
- **본문**: GBIZ 번호만 (다른 내용 절대 금지)
- **구체적 표현**: 포괄적/추상적 표현 금지

#### 예시
```bash
# ✅ 올바른 예시
git crm-ios-commit -m "feat: 결제 수단별 인센티브 설정 UI 구현

GBIZ-19375"

# ✅ 구체적인 예시
git crm-ios-commit -m "fix: BookV2RouterTests DTO 초기화 파라미터 누락 수정

GBIZ-19838"

# ❌ 포괄적 표현 (금지)
git crm-ios-commit -m "fix: 에러 수정

GBIZ-19838"

# ❌ 본문에 설명 추가 (금지)
git crm-ios-commit -m "feat: UI 구현

카드, 현금 각각 설정 가능

GBIZ-19375"
```

### 6단계: 사용자 확인

```
"[호칭], 다음과 같이 커밋하시겠습니까?

커밋 메시지:
feat: 결제 수단별 인센티브 설정 UI 구현

GBIZ-19375

변경 파일:
- Views/PaymentSettingView.swift (수정)
- ViewModels/PaymentSettingViewModel.swift (추가)

[Y] 커밋 / [N] 취소 / [E] 메시지 수정"
```

### 7단계: 커밋 실행

```bash
git add <specific-file-path>  # 선택적 추가 (git add . 금지)
git crm-ios-commit -m "$(cat <<'EOF'
<type>: <제목>

GBIZ-{번호}
EOF
)"
```

## 커밋 분리 전략

**원칙: 빌드 가능한 최소 단위로 기능별 커밋**

### 분리 기준
1. Model/DTO 정의
2. Router 구현
3. Repository 구현
4. ViewModel 구현
5. View 구현
6. 테스트 코드 추가

### 분리 제안
```
"[호칭], 변경사항이 여러 기능에 걸쳐 있습니다.
다음과 같이 커밋을 분리하시겠습니까?

1. feat: 모델 구조 추가 (Models/*.swift)
2. feat: UI 구현 (Views/*.swift)
3. test: 테스트 코드 추가 (Tests/*.swift)"
```

### 분리 예시

#### Mock 관련 커밋
```bash
# 1. Mock 델리게이트 먼저 커밋
git add NetworkSystemTests/RouterTests/Common/MockRouterConnectDelegate.swift
git crm-ios-commit -m "$(cat <<'EOF'
test: RouterTests용 MockRouterConnectDelegate 추가

GBIZ-19840
EOF
)"

# 2. 테스트 파일 커밋
git add NetworkSystemTests/RouterTests/ShopV2RouterTests.swift
git crm-ios-commit -m "$(cat <<'EOF'
test: ShopV2Router 테스트 코드 추가

GBIZ-19840
EOF
)"
```

#### 테스트 수정 커밋
```bash
# DTO 구조 변경에 따른 테스트 수정
git add NetworkSystemTests/RouterTests/BookV2RouterTests.swift
git crm-ios-commit -m "$(cat <<'EOF'
fix: BookV2RouterTests DTO 초기화 파라미터 누락 수정

GBIZ-19838
EOF
)"
```

#### 문서 수정 커밋
```bash
# 스킬 문서 개선
git add .claude/skills/commit/SKILL.md
git crm-ios-commit -m "$(cat <<'EOF'
doc: crm-ios-commit 스킬 커밋 분리 예시 추가

GBIZ-19915
EOF
)"
```

## 금지 사항

- ⛔ `git add .` 사용 금지 (선택적 추가만)
- ⛔ 본문에 GBIZ 외 내용 추가 금지
- ⛔ Co-Authored-By, 이모지 등 추가 금지
- ⛔ 빌드 실패하는 코드 커밋 금지
- ⛔ 포괄적/추상적 커밋 메시지 금지

## 참조 문서

- Git 가이드: `.docs/GIT_GUIDE.md`
- 호칭: `CLAUDE.local.md`

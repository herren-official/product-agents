---
name: b2b-android-command-creator
description: 새로운 커맨드 생성. "커맨드 만들어줘", "command 생성", "슬래시 명령어 추가" 요청 시 사용. 스킬이 아닌 커맨드를 만들 때 사용
allowed-tools: Bash, Read, Write, Edit
user-invocable: true
---

# 커맨드 생성 스킬

새로운 Claude Code 슬래시 커맨드를 올바른 형식으로 생성한다.

## ⚠️ 커맨드 vs 스킬 (절대 혼동 금지!)

| 구분 | 커맨드 (Command) | 스킬 (Skill) |
|------|-----------------|-------------|
| 위치 | `.claude/commands/이름.md` | `.claude/skills/폴더명/SKILL.md` |
| 발동 | **수동** (`/명령어` 입력) | **자동** (Claude 판단) |
| 파일명 | `자유.md` (단일 파일) | `SKILL.md` (대문자, 고정) |
| 구조 | 단일 .md 파일 | 폴더 + SKILL.md |
| bash 실행 | `!명령어` 직접 실행 | 지침으로 안내 |

## 커맨드 생성 단계

### 1단계: 파일 생성
```bash
touch .claude/commands/{커맨드명}.md
```
- 커맨드명: 소문자, 하이픈 사용 (예: `create-test`, `run-lint`)
- 호출: `/{커맨드명}` (예: `/create-test`)

### 2단계: 커맨드 파일 작성

```markdown
---
description: "{기능 설명}"
argument-hint: "[인자1] [인자2]"
allowed-tools: ["bash", "read", "write", "edit", "grep"]
---

# {커맨드 제목}

{설명}

## 실행 내용

!echo "=== 시작 ==="
!{bash 명령어}

위 결과를 분석하여:

## 1. {단계명}
- {지침}

## 2. {단계명}
- {지침}

## 핵심 규칙
- {규칙}
```

## 메타데이터 필드

| 필드 | 필수 | 설명 |
|------|------|------|
| `description` | ✅ | 커맨드 설명 (따옴표로 감싸기) |
| `argument-hint` | ❌ | 인자 힌트 표시 (예: `[파일경로]`) |
| `allowed-tools` | ❌ | 사용 가능한 도구 (배열 형식) |

## `!` 명령어 (커맨드 전용)

커맨드에서는 `!`로 시작하면 bash 명령어가 **직접 실행**됨

```markdown
## 현재 상태 확인
!git status --porcelain
!git diff --staged

위 결과를 분석하여 다음 작업 수행:
```

**주의**: 스킬에서는 `!` 명령어 사용 불가!

## 인자 사용 ($ARGUMENTS)

사용자가 전달한 인자는 `$ARGUMENTS`로 접근

```markdown
---
description: "파일 분석"
argument-hint: "[파일경로]"
---

# 파일 분석

!cat $ARGUMENTS
```

호출: `/analyze src/main.kt` → `$ARGUMENTS = src/main.kt`

## 커맨드 예시

### 단순 커맨드
```markdown
---
description: "빌드 실행"
allowed-tools: ["bash"]
---

# 빌드

!./gradlew assembleDevDebug
```

### 인자 포함 커맨드
```markdown
---
description: "특정 테스트 실행"
argument-hint: "[테스트 클래스명]"
allowed-tools: ["bash"]
---

# 테스트 실행

!./gradlew test --tests "$ARGUMENTS"
```

## 하위 폴더 커맨드

```
.claude/commands/
├── create-commit.md      # /create-commit
├── create-pr.md          # /create-pr
└── test/
    └── test-coverage.md  # /test:test-coverage
```

하위 폴더는 `:` 구분자로 호출

## 생성 완료 후 확인

```bash
ls -la .claude/commands/
cat .claude/commands/{커맨드명}.md
```

## 테스트

```
/{커맨드명}
/{커맨드명} 인자값
```

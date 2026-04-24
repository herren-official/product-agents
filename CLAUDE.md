# product-agents — AI-DLC 에이전트·스킬 레포

이 레포는 AI-DLC 전 공정의 **에이전트**와 **스킬** 파일을 중앙 관리합니다.
**디렉토리 번호 = 작업 순서** — 순서대로 실행하면 AI-DLC 흐름이 완성됩니다.

## AI-DLC 흐름 (에이전트)

```
01-inception/   → requirements-analyst, application-designer, cross-domain-checker
02-spec/        → units-generator, spec-writer
03-plan/        → code-planner, functional-designer
04-build/       → debugger
05-test/        → tester
06-review/      → kotlin-reviewer, typescript-reviewer, code-simplifier
07-ship/        → ship-checklist
08-operations/  → incident-analyzer
```

서비스 전용 에이전트는 동일 공정 폴더에 `<service>-<name>.md`로 배치:
`04-build/b2c-ios-feature-builder.md`, `05-test/b2c-ios-test-builder.md` 등.

## 스킬

```
skills/<service>/<skill-name>/SKILL.md   — 서비스별 Claude Code 스킬
```

- 레포는 2단 중첩(`skills/b2c-iOS/commit/SKILL.md`) 으로 관리
- `setup.sh`가 `~/.claude/skills/b2c-ios-commit/` 평탄 링크로 풀어줌
- Claude Code 호출: `/b2c-ios-commit`, `/b2c-ios-pr` 등

```
services/       — 서비스별 레포 → 공정별 에이전트·스킬 매핑
registry.yaml   — 전체 에이전트 + 스킬 카탈로그
setup.sh        — ~/.claude/agents/ + ~/.claude/skills/ 심볼릭 링크 설치
```

## 사용법

서비스 레포에서 작업 시작 시:
1. `services/<service-name>.md` 읽기 — 공정별 에이전트·스킬 확인
2. 현재 공정에 맞는 에이전트·스킬 호출
3. 실체는 `setup.sh`가 만든 심볼릭 링크를 통해 이 레포의 파일을 가리킴

## 서비스 → 매핑 파일

| 서비스 | 매핑 파일 |
|--------|----------|
| gongbiz-crm-b2b | `services/gongbiz-crm-b2b.md` |
| gongbiz-b2c | `services/gongbiz-b2c.md` |
| instaget | `services/instaget.md` |
| fineadple | `services/fineadple.md` |

## 새 에이전트 추가

1. 해당 공정 디렉토리(`01`~`08`)에 `<agent-name>.md` 작성
   - 서비스 전용이면 `<service>-<agent-name>.md`
2. `registry.yaml` `agents:` 섹션에 항목 추가
3. `./setup.sh` 실행 → 심볼릭 링크 갱신
4. 관련 `services/*.md` 테이블에 등록

## 새 스킬 추가

1. `skills/<service>/<skill-name>/SKILL.md` 작성
   - 파일명 `SKILL.md` 고정 (Claude Code 표준)
   - frontmatter `name:` 필드는 `<service-lowercase>-<skill-name>`
2. `registry.yaml` `skills:` 섹션에 항목 추가
3. `./setup.sh` 실행 → `~/.claude/skills/<service-lowercase>-<skill-name>/` 평탄 링크 생성
4. 관련 `services/*.md`에 등록

## 설치

```bash
cd ~/git/product-agents
./setup.sh
```

완료 후 `~/.claude/agents/` + `~/.claude/skills/` 에 심볼릭 링크 생성. Claude Code 재시작 불필요.

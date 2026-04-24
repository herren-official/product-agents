# product-agents — AI-DLC 에이전트 레포

이 레포는 AI-DLC 전 공정의 에이전트/스킬 파일을 중앙 관리합니다.
**디렉토리 번호 = 작업 순서** — 순서대로 실행하면 AI-DLC 흐름이 완성됩니다.

## AI-DLC 흐름

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

```
services/       — 서비스별 레포 → 공정별 에이전트 매핑
registry.yaml   — 전체 에이전트 목록
setup.sh        — ~/.claude/agents/ 심볼릭 링크 설치
```

## 에이전트 사용법

서비스 레포에서 작업 시작 시:
1. `services/<service-name>.md` 읽기 — 현재 레포의 공정별 에이전트 확인
2. 현재 공정 번호에 맞는 에이전트를 `~/.claude/agents/`에서 호출
3. 에이전트는 `setup.sh`로 설치된 심볼릭 링크를 통해 이 레포의 파일을 가리킴

## 서비스 → 에이전트 매핑

| 서비스 | 매핑 파일 |
|--------|----------|
| gongbiz-crm-b2b | `services/gongbiz-crm-b2b.md` |
| gongbiz-b2c | `services/gongbiz-b2c.md` |
| instaget | `services/instaget.md` |
| fineadple | `services/fineadple.md` |

## 새 에이전트 추가

1. 해당 공정 디렉토리(`01`~`08`)에 `<agent-name>.md` 작성
2. `registry.yaml`에 항목 추가
3. `./setup.sh` 실행 → 심볼릭 링크 갱신
4. 관련 `services/*.md` 테이블에 에이전트 등록

## 설치

```bash
cd ~/git/product-agents
./setup.sh
```

완료 후 `~/.claude/agents/`에 심볼릭 링크 생성됨. Claude Code 재시작 불필요.

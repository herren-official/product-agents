# fineadple

파인앳플 서비스 레포-에이전트 매핑.

AI-DLC 흐름: `01 Inception` → `02 Spec` → `03 Plan` → `04 Build` → `05 Test` → `06 Review` → `07 Ship`

| 레포 | 플랫폼 | 01 Inception | 02 Spec | 03 Plan | 04 Build | 05 Test | 06 Review | 07 Ship | 비고 |
|------|--------|-------------|---------|---------|----------|---------|-----------|---------|------|
| fineadple-server | Kotlin/Spring | requirements-analyst, cross-domain-checker | units-generator, spec-writer | functional-designer | debugger | tester | kotlin-reviewer, code-simplifier | ship-checklist | 스킬: [skills/fineadple-backend/](../skills/fineadple-backend/) |
| fineadple-b2c-frontend | TypeScript/React | requirements-analyst | spec-writer | — | debugger | tester | typescript-reviewer, code-simplifier | ship-checklist | |

## 스킬 매핑 (fineadple-server 전용)

| 공정 | 스킬 | 호출 방식 |
|------|------|----------|
| 06 Review | [`fineadple-backend-pr-reviewer`](../skills/fineadple-backend/pr-reviewer/SKILL.md), [`fineadple-backend-refactoring-assistant`](../skills/fineadple-backend/refactoring-assistant/SKILL.md) | `/fineadple-backend-pr-reviewer`, `/fineadple-backend-refactoring-assistant` |
| 07 Ship | [`fineadple-backend-commit-push`](../skills/fineadple-backend/commit-push/SKILL.md), [`fineadple-backend-pr-creator`](../skills/fineadple-backend/pr-creator/SKILL.md), [`fineadple-backend-pr-comment-reply`](../skills/fineadple-backend/pr-comment-reply/SKILL.md) | `/fineadple-backend-commit-push`, `/fineadple-backend-pr-creator`, `/fineadple-backend-pr-comment-reply` |

# instaget

인스타겟 서비스 레포-에이전트 매핑.

AI-DLC 흐름: `01 Inception` → `02 Spec` → `03 Plan` → `04 Build` → `05 Test` → `06 Review` → `07 Ship`

| 레포 | 플랫폼 | 01 Inception | 02 Spec | 03 Plan | 04 Build | 05 Test | 06 Review | 07 Ship | 비고 |
|------|--------|-------------|---------|---------|----------|---------|-----------|---------|------|
| instaget-server | Kotlin/Spring | requirements-analyst, cross-domain-checker | units-generator, spec-writer | **code-planner**, functional-designer | debugger | tester | kotlin-reviewer, code-simplifier | ship-checklist | AI-DLC 파일럿 대상, wiki 기반 분석 · 스킬: [skills/instaget-backend/](../skills/instaget-backend/) |
| instaget-b2c-frontend | TypeScript/React | requirements-analyst | spec-writer | — | debugger | tester | typescript-reviewer, code-simplifier | ship-checklist | |

## 스킬 매핑 (instaget-server 전용)

| 공정 | 스킬 | 호출 방식 |
|------|------|----------|
| 06 Review | [`instaget-backend-pr-reviewer`](../skills/instaget-backend/pr-reviewer/SKILL.md), [`instaget-backend-refactoring-assistant`](../skills/instaget-backend/refactoring-assistant/SKILL.md) | `/instaget-backend-pr-reviewer`, `/instaget-backend-refactoring-assistant` |
| 07 Ship | [`instaget-backend-commit-push`](../skills/instaget-backend/commit-push/SKILL.md), [`instaget-backend-pr-creator`](../skills/instaget-backend/pr-creator/SKILL.md), [`instaget-backend-pr-comment-reply`](../skills/instaget-backend/pr-comment-reply/SKILL.md) | `/instaget-backend-commit-push`, `/instaget-backend-pr-creator`, `/instaget-backend-pr-comment-reply` |

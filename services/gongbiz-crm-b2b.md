# gongbiz-crm-b2b

공비서 CRM B2B 서비스 레포-에이전트 매핑.

AI-DLC 흐름: `01 Inception` → `02 Spec` → `03 Plan` → `04 Build` → `05 Test` → `06 Review` → `07 Ship`

| 레포 | 플랫폼 | 01 Inception | 02 Spec | 03 Plan | 04 Build | 05 Test | 06 Review | 07 Ship | 비고 |
|------|--------|-------------|---------|---------|----------|---------|-----------|---------|------|
| gongbiz-crm-b2b-backend | Kotlin/Spring | requirements-analyst, cross-domain-checker | units-generator, spec-writer | **code-planner**, functional-designer | debugger | tester | kotlin-reviewer, code-simplifier | ship-checklist | wiki 기반 분석 |
| gongbiz-crm-b2b-front | TypeScript/React | requirements-analyst | spec-writer | — | debugger | tester | typescript-reviewer, code-simplifier | ship-checklist | |
| gongbiz-crm-b2b-web | Next.js | requirements-analyst | spec-writer | — | debugger | tester | typescript-reviewer, code-simplifier | ship-checklist | |
| gongbiz-crm-android | Kotlin/Android | requirements-analyst | spec-writer, **b2b-android-tc-generator** | — | debugger | **b2b-android-ui-test-planner**, **b2b-android-ui-test-generator**, **b2b-android-ui-test-healer**, **b2b-android-unit-test-planner**, **b2b-android-unit-test-generator**, **b2b-android-unit-test-healer**, tester | kotlin-reviewer | ship-checklist | 서비스 전용 에이전트 7개 + 스킬 14개 |
| gongbiz-crm-iOS | Swift | requirements-analyst | — | — | — | — | — | — | 레포 내 에이전트 12개 완비 |

> 굵은 글씨는 `service:gongbiz-crm-b2b-android` 스코프 전용 에이전트. 나머지는 공용.

## 스킬 매핑 (gongbiz-crm-b2b-android 전용)

| 공정 | 스킬 | 호출 방식 |
|------|------|----------|
| 01 Inception / 02 Spec | `b2b-android-backlog-refiner`, `b2b-android-prd` | `/b2b-android-backlog-refiner`, `/b2b-android-prd` |
| 03 Plan | `b2b-android-work` | `/b2b-android-work` |
| 04 Build | `b2b-android-compose-ui`, `b2b-android-create-api`, `b2b-android-string-resource` | `/b2b-android-compose-ui` 등 |
| 05 Test | `b2b-android-create-mock-data`, `b2b-android-unittest-agent` | `/b2b-android-unittest-agent` 등 |
| 06 Review | `b2b-android-import-cleaner`, `b2b-android-review-pr` | `/b2b-android-review-pr` 등 |
| 07 Ship | `b2b-android-branch`, `b2b-android-commit`, `b2b-android-pr` | `/b2b-android-commit`, `/b2b-android-pr` 등 |
| 메타 | `b2b-android-command-creator` | `/b2b-android-command-creator` |

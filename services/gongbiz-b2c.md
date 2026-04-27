# gongbiz-b2c

공비서 B2C 서비스 레포-에이전트 매핑.

AI-DLC 흐름: `01 Inception` → `02 Spec` → `03 Plan` → `04 Build` → `05 Test` → `06 Review` → `07 Ship`

## 에이전트 매핑

| 레포 | 플랫폼 | 01 Inception | 02 Spec | 03 Plan | 04 Build | 05 Test | 06 Review | 07 Ship | 비고 |
|------|--------|-------------|---------|---------|----------|---------|-----------|---------|------|
| gongbiz-b2c-frontend | TypeScript/React | requirements-analyst | spec-writer | — | debugger | tester | typescript-reviewer, code-simplifier | ship-checklist | 레포 내 컨벤션 11개 + ESLint 완비 |
| gongbiz-b2c-android | Kotlin/Android | requirements-analyst | — | — | **b2c-android-build-checker**, debugger | **b2c-android-unit-tester** | **b2c-android-resource-cleaner**, kotlin-reviewer, code-simplifier | ship-checklist | `.docs/` · `.claude/` · `.b2cspec/` · `.vibe-ready/` (08 Operations: **b2c-android-crashlytics-analyzer**) |
| gongbiz-b2c-iOS | Swift/SwiftUI/TCA/Tuist | requirements-analyst, **b2c-ios-planning-orchestrator**, **b2c-ios-issue-analyzer** | **b2c-ios-task-planner** | **b2c-ios-code-analyzer**, **b2c-ios-design-analyzer** | **b2c-ios-feature-builder**, **b2c-ios-ui-builder**, **b2c-ios-network-builder**, debugger | **b2c-ios-test-builder** | **b2c-ios-docs-reviewer**, code-simplifier | **b2c-ios-git-reviewer**, ship-checklist | `.docs/` · `.claude/` · `.maestro/` · `.sim-screenshots/` |

> 굵은 글씨는 서비스 스코프 전용 에이전트 (`service:gongbiz-b2c-iOS` / `service:gongbiz-b2c-android`). 나머지는 공용.

## 스킬 매핑 (gongbiz-b2c-iOS 전용)

| 공정 | 스킬 | 호출 방식 |
|------|------|----------|
| 01 Inception / 02 Spec | `b2c-ios-plan`, `b2c-ios-notion-read`, `b2c-ios-notion-update`, `b2c-ios-notion-create`, `b2c-ios-from-issue`, `b2c-ios-triage-issues` | `/b2c-ios-plan`, `/b2c-ios-from-issue`, `/b2c-ios-triage-issues` 등 |
| 03 Plan | `b2c-ios-figma-analyze`, `b2c-ios-feature-explore`, `b2c-ios-design-system-explore` | `/b2c-ios-figma-analyze` 등 |
| 04 Build | `b2c-ios-build-verify` | `/b2c-ios-build-verify` |
| 05 Test | `b2c-ios-test-explore` | `/b2c-ios-test-explore` |
| 06 Review | `b2c-ios-pre-commit-checker`, `b2c-ios-pre-pr-review`, `b2c-ios-docs-review` | `/b2c-ios-pre-commit-checker` 등 |
| 07 Ship | `b2c-ios-branch-strategy`, `b2c-ios-commit`, `b2c-ios-pr`, `b2c-ios-review-fix` | `/b2c-ios-commit`, `/b2c-ios-pr` 등 |

## 스킬 매핑 (gongbiz-b2c-android 전용)

| 공정 | 스킬 | 호출 방식 |
|------|------|----------|
| 02 Spec | `b2c-android-prd` | `/b2c-android-prd` |
| 03 Plan | `b2c-android-analyze-module`, `b2c-android-explain-flow` | `/b2c-android-analyze-module` 등 |
| 04 Build | `b2c-android-add-event`, `b2c-android-create-api`, `b2c-android-create-feature`, `b2c-android-string-resource` | `/b2c-android-create-api` 등 |
| 05 Test | `b2c-android-create-mock-data`, `b2c-android-test-setup` | `/b2c-android-create-mock-data` 등 |
| 06 Review | `b2c-android-review-pr` | `/b2c-android-review-pr` |
| 07 Ship | `b2c-android-create-branch`, `b2c-android-create-commit`, `b2c-android-create-pr`, `b2c-android-my-pr`, `b2c-android-ship` | `/b2c-android-ship`, `/b2c-android-create-pr` 등 |

## 참고

- 에이전트 정의: `01-inception/` ~ `07-ship/` 내 `b2c-ios-*.md` 파일
- 스킬 정의: `skills/b2c-iOS/<skill-name>/SKILL.md`
- 설치: `./setup.sh` 실행 → `~/.claude/agents/`, `~/.claude/skills/` 에 심볼릭 링크 생성

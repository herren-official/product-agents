# gongbiz-crm-b2b

공비서 CRM B2B 서비스 레포-에이전트 매핑.

AI-DLC 흐름: `01 Inception` → `02 Spec` → `03 Plan` → `04 Build` → `05 Test` → `06 Review` → `07 Ship`

## 에이전트 매핑

| 레포 | 플랫폼 | 01 Inception | 02 Spec | 03 Plan | 04 Build | 05 Test | 06 Review | 07 Ship | 비고 |
|------|--------|-------------|---------|---------|----------|---------|-----------|---------|------|
| gongbiz-crm-b2b-backend | Kotlin/Spring | requirements-analyst, cross-domain-checker | units-generator, spec-writer | **code-planner**, functional-designer | debugger | tester | kotlin-reviewer, code-simplifier | ship-checklist | wiki 기반 분석 |
| gongbiz-crm-b2b-front | TypeScript/React | requirements-analyst | spec-writer | — | debugger | tester | typescript-reviewer, code-simplifier | ship-checklist | |
| gongbiz-crm-b2b-web | Next.js | requirements-analyst | spec-writer | — | debugger | tester | typescript-reviewer, code-simplifier | ship-checklist | |
| gongbiz-crm-android | Kotlin/Android | requirements-analyst | spec-writer, **b2b-android-tc-generator** | — | debugger | **b2b-android-ui-test-planner**, **b2b-android-ui-test-generator**, **b2b-android-ui-test-healer**, **b2b-android-unit-test-planner**, **b2b-android-unit-test-generator**, **b2b-android-unit-test-healer**, tester | kotlin-reviewer | ship-checklist | `.docs/`(컨벤션·디자인시스템·테스트 가이드) · `.claude/`(에이전트·명령) · `.scripts/`(리소스 정리·UI 테스트 러너) |
| gongbiz-crm-iOS | Swift/UIKit/RxSwift/MVVM | requirements-analyst, **crm-ios-notion-analyzer**, **crm-ios-slack-analyzer**, **crm-ios-figma-ui-analyzer**, **crm-ios-figma-policy-analyzer**, **crm-ios-component-mapper** | **crm-ios-task-planner**, **crm-ios-notion-writer** | **crm-ios-code-analyzer**, **crm-ios-side-effect-analyzer** | **crm-ios-task-executor**, **crm-ios-code-implementer**, debugger | **crm-ios-test-writer**, **crm-ios-build-checker** | **crm-ios-implementation-verifier**, **crm-ios-side-effect-verifier**, code-simplifier | ship-checklist | `.docs/`(빌드·Git·컨벤션·UI 테스트 가이드) |

> 굵은 글씨는 서비스 스코프 전용 에이전트 (`service:gongbiz-crm-b2b-android` / `service:gongbiz-crm-iOS`). 나머지는 공용.

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

## 스킬 매핑 (gongbiz-crm-iOS 전용)

| 공정 | 스킬 | 호출 방식 |
|------|------|----------|
| 01 Inception / 02 Spec | `crm-ios-figma-analyze`, `crm-ios-task-planner` | `/crm-ios-figma-analyze`, `/crm-ios-task-planner` |
| 04 Build | `crm-ios-task-executor` | `/crm-ios-task-executor` |
| 05 Test | `crm-ios-repository-test`, `crm-ios-router-test`, `crm-ios-usecase-test`, `crm-ios-viewmodel-test`, `crm-ios-test-runner`, `crm-ios-coverage-checker` | `/crm-ios-repository-test` 등 |
| 06 Review | `crm-ios-pre-commit-checker`, `crm-ios-document-checker`, `crm-ios-doc-manager` | `/crm-ios-pre-commit-checker` 등 |
| 07 Ship | `crm-ios-branch-creator`, `crm-ios-commit`, `crm-ios-pr` | `/crm-ios-commit`, `/crm-ios-pr` 등 |
| 08 Operations | `crm-ios-crashlytics-analyze`, `crm-ios-crashlytics-fix` | `/crm-ios-crashlytics-analyze` 등 |

## 참고

- 에이전트 정의: `01-inception/` ~ `07-ship/` 내 `b2b-android-*.md` / `crm-ios-*.md` 파일
- 스킬 정의: `skills/b2b-Android/<skill-name>/SKILL.md`, `skills/crm-iOS/<skill-name>/SKILL.md`
- 설치: `./setup.sh` 실행 → `~/.claude/agents/`, `~/.claude/skills/` 에 심볼릭 링크 생성
- iOS 레포 기반 브랜치: `v.8.12.22` (아직 develop 미머지 상태에서 이관)

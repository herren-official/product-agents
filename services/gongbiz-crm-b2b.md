# gongbiz-crm-b2b

공비서 CRM B2B 서비스 레포-에이전트 매핑.

AI-DLC 흐름: `01 Inception` → `02 Spec` → `03 Plan` → `04 Build` → `05 Test` → `06 Review` → `07 Ship`

## 에이전트 매핑

| 레포 | 플랫폼 | 01 Inception | 02 Spec | 03 Plan | 04 Build | 05 Test | 06 Review | 07 Ship | 비고 |
|------|--------|-------------|---------|---------|----------|---------|-----------|---------|------|
| gongbiz-crm-b2b-backend | Kotlin/Spring | requirements-analyst, cross-domain-checker | units-generator, spec-writer | **code-planner**, functional-designer | debugger | tester | kotlin-reviewer, code-simplifier | ship-checklist | wiki 기반 분석 |
| gongbiz-crm-b2b-front | TypeScript/React | requirements-analyst | spec-writer | — | debugger | tester | typescript-reviewer, code-simplifier | ship-checklist | |
| gongbiz-crm-b2b-web | Next.js | requirements-analyst | spec-writer | — | debugger | tester | typescript-reviewer, code-simplifier | ship-checklist | |
| gongbiz-crm-android | Kotlin/Android | requirements-analyst | spec-writer, **b2b-android-tc-generator** | — | debugger | **b2b-android-ui-test-planner**, **b2b-android-ui-test-generator**, **b2b-android-ui-test-healer**, **b2b-android-unit-test-planner**, **b2b-android-unit-test-generator**, **b2b-android-unit-test-healer**, tester | kotlin-reviewer | ship-checklist | `.docs/` — 브랜치/커밋/PR 컨벤션, `conventions/`(프로젝트 컨벤션/구조·스트링 리소스·뷰모델 테스트 컨벤션), `design-system/`(buttons·colors·figma-guide·form-controls·iconography·modals·navigation·typography 등 13건)·`design-system.md`·jacoco 커버리지 가이드·`test/`(branch-coverage·examples·mock-patterns·README)·`ui-test.md`. `.claude/commands/` — 11건(브랜치/커밋/PR 생성, 리소스 정리, 노션 카드 생성, Compose UI/유닛 테스트 생성 + 셸 스크립트, B2B UI 테스트 실행). `.scripts/` — `remove_unused_resources.py`, `run_b2b_ui_test.sh`. |
| gongbiz-crm-iOS | Swift/UIKit/RxSwift/MVVM | requirements-analyst, **crm-ios-notion-analyzer**, **crm-ios-slack-analyzer**, **crm-ios-figma-ui-analyzer**, **crm-ios-figma-policy-analyzer**, **crm-ios-component-mapper** | **crm-ios-task-planner**, **crm-ios-notion-writer** | **crm-ios-code-analyzer**, **crm-ios-side-effect-analyzer** | **crm-ios-task-executor**, **crm-ios-code-implementer**, debugger | **crm-ios-test-writer**, **crm-ios-build-checker** | **crm-ios-implementation-verifier**, **crm-ios-side-effect-verifier**, code-simplifier | ship-checklist | `.docs/` — `BUILD_GUIDE`·`GIT_GUIDE`·`FILE_MANAGEMENT`·`CLAUDE_DOCUMENT_CHECKLIST`·`DOCUMENT_CHECK_TEMPLATE`·`NOTION_TASK_GUIDE`, `conventions/`(API 구현·CONVENTIONS·DESIGN_SYSTEM·MOCK 커스텀 응답·Router/UseCase/ViewModel 테스트·RxSwift+MVVM·SwiftUI·UIKit·테스트 코드 가이드 13건), `UITest/`(접근성·가이드·시나리오·트러블슈팅 4건). 루트 `Documents/`(빈 폴더). (v.8.12.22 기반) |

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

# product-agents

헤렌 AI-DLC 공정별 에이전트 및 스킬 정의 레포.

모든 에이전트와 스킬은 이 레포에서 단일 관리됩니다.
Claude Code는 `~/.claude/agents/` 및 `~/.claude/skills/` 심볼릭 링크를 통해 호출합니다.

---

## AI-DLC 흐름

**디렉토리 번호 = 작업 순서.** 순서대로 실행하면 AI-DLC 전 공정이 완성됩니다.

```
요구사항 발생
    ↓
[01 Inception]
  requirements-analyst   → 요구사항 정제 + outcome_metric 확인
  application-designer   → 컴포넌트 설계 + API 목록
  cross-domain-checker   → 크로스-도메인 영향도 분석
    ↓
[02 Spec]
  units-generator        → 플랫폼별 유닛 분해
  spec-writer            → 유닛별 스펙 확정 (완료 기준 포함)
    ↓
[03 Plan]
  functional-designer    → 유닛별 비즈니스 로직 상세 설계
  code-planner           → wiki 기반 구현 체크리스트 수립
    ↓
[04 Build]
  (구현)
  debugger               → 에러 발생 시 원인 진단 → 수정 방향 도출
    ↓
[05 Test]
  tester                 → 테스트 전략 수립 + 테스트 작성
    ↓
[06 Review]
  kotlin-reviewer        → Kotlin/Spring Boot 코드 리뷰
  typescript-reviewer    → TypeScript/React 코드 리뷰
  code-simplifier        → 불필요한 복잡도 제거
    ↓
[07 Ship]
  ship-checklist         → 배포 전 최종 검증 게이트
    ↓
[08 Operations]
  incident-analyzer      → Sentry 장애 분석 + 대응 방안 도출
```

**서비스 전용 에이전트**는 공정별 디렉토리에 `<service>-<agent-name>.md` 형식으로 함께 배치됩니다
(예: `04-build/b2c-ios-feature-builder.md` — gongbiz-b2c-iOS 전용 Feature 빌더).

---

## 구조

```
product-agents/
├── 01-inception/
│   ├── requirements-analyst.md          # 공용: 요구사항 분석
│   ├── application-designer.md          # 공용: 컴포넌트 설계
│   ├── cross-domain-checker.md          # 공용: 크로스-도메인 참조 검증
│   └── b2c-ios-planning-orchestrator.md # 서비스 전용: b2c-iOS 기획 조율
├── 02-spec/
│   ├── units-generator.md               # 공용
│   ├── spec-writer.md                   # 공용
│   └── b2c-ios-task-planner.md          # 서비스 전용
├── 03-plan/
│   ├── code-planner.md                  # 공용
│   ├── functional-designer.md           # 공용
│   ├── b2c-ios-code-analyzer.md         # 서비스 전용
│   └── b2c-ios-design-analyzer.md       # 서비스 전용
├── 04-build/
│   ├── debugger.md                      # 공용
│   ├── b2c-ios-feature-builder.md       # 서비스 전용
│   ├── b2c-ios-ui-builder.md            # 서비스 전용
│   └── b2c-ios-network-builder.md       # 서비스 전용
├── 05-test/
│   ├── tester.md                        # 공용
│   └── b2c-ios-test-builder.md          # 서비스 전용
├── 06-review/
│   ├── kotlin-reviewer.md               # 공용
│   ├── typescript-reviewer.md           # 공용
│   ├── code-simplifier.md               # 공용
│   └── b2c-ios-docs-reviewer.md         # 서비스 전용
├── 07-ship/
│   ├── ship-checklist.md                # 공용
│   └── b2c-ios-git-reviewer.md          # 서비스 전용
├── 08-operations/
│   └── incident-analyzer.md             # 공용
├── skills/                              # 서비스별 Claude Code 스킬
│   └── b2c-iOS/
│       ├── plan/SKILL.md
│       ├── commit/SKILL.md
│       ├── pr/SKILL.md
│       └── ... (16개)
├── services/                            # 서비스별 레포 → 공정별 에이전트 매핑
│   ├── gongbiz-crm-b2b.md
│   ├── gongbiz-b2c.md
│   ├── instaget.md
│   └── fineadple.md
├── registry.yaml                        # 전체 에이전트 + 스킬 카탈로그
└── setup.sh                             # 심볼릭 링크 설치 스크립트
```

---

## 설치

최초 설정 시 1회 실행합니다.

```bash
git clone https://github.com/herren-official/product-agents.git ~/git/product-agents
~/git/product-agents/setup.sh
```

이후 에이전트·스킬 업데이트는 `git pull`만으로 자동 반영됩니다 (심볼릭 링크이므로 재실행 불필요).

새 에이전트·스킬이 추가된 경우 `setup.sh`를 다시 실행합니다.

---

## 동작 방식

### 에이전트

```
product-agents/06-review/kotlin-reviewer.md   (소스 - Git 관리)
        ↑ 심볼릭 링크
~/.claude/agents/kotlin-reviewer.md           (Claude Code가 읽는 위치)
```

`setup.sh`가 `01-inception/` ~ `08-operations/` 하위 `.md` 파일을
`~/.claude/agents/`에 flat 심볼릭 링크로 연결합니다.

### 스킬

```
product-agents/skills/b2c-iOS/commit/SKILL.md   (소스 - Git 관리, 2단 중첩)
        ↑ 심볼릭 링크 (setup.sh가 평탄화)
~/.claude/skills/b2c-ios-commit/                (Claude Code가 읽는 위치)
        └── SKILL.md
```

레포 내부는 **서비스 폴더로 그룹핑**(`skills/<service>/<skill-name>/`) 하지만,
Claude Code는 `~/.claude/skills/` 아래 **평탄 구조**만 인식합니다.
`setup.sh`가 서비스 폴더를 소문자 프리픽스로 풀어서 각 스킬을 평탄 링크로 만듭니다:

- `skills/b2c-iOS/commit/` → `~/.claude/skills/b2c-ios-commit/`
- `skills/b2c-iOS/pr/` → `~/.claude/skills/b2c-ios-pr/`

슬래시 커맨드 호출: `/b2c-ios-commit`, `/b2c-ios-pr` 등.

---

## 서비스별 매핑

각 서비스 레포에서 작업 시작 시 `services/<service-name>.md`를 먼저 확인합니다.
현재 공정에 해당하는 에이전트·스킬을 호출합니다.

| 서비스 | 매핑 파일 |
|--------|----------|
| gongbiz-crm-b2b | `services/gongbiz-crm-b2b.md` |
| gongbiz-b2c | `services/gongbiz-b2c.md` |
| instaget | `services/instaget.md` |
| fineadple | `services/fineadple.md` |

---

## 에이전트 추가

1. 해당 공정 디렉토리(`01`~`08`)에 `<agent-name>.md` 작성
   - 서비스 전용이면 `<service>-<agent-name>.md` (예: `b2c-ios-feature-builder.md`)
2. `registry.yaml` `agents:` 섹션에 항목 추가
3. `./setup.sh` 실행 → 심볼릭 링크 갱신
4. 관련 `services/*.md` 테이블에 에이전트 등록
5. PR 머지 → 각 환경에서 `git pull`

## 스킬 추가

1. `skills/<service>/<skill-name>/SKILL.md` 작성
   - 서비스 폴더가 없으면 먼저 생성 (예: `skills/gongbiz-crm-b2b/`)
   - `SKILL.md` **파일명은 고정** (Claude Code 표준)
   - frontmatter의 `name:` 필드는 `<service-lowercase>-<skill-name>` 형식
2. `registry.yaml` `skills:` 섹션에 항목 추가
3. `./setup.sh` 실행 → `~/.claude/skills/<service-lowercase>-<skill-name>/` 평탄 링크 생성
4. 관련 `services/*.md`에 스킬 등록
5. PR 머지 → 각 환경에서 `git pull`

# product-agents

헤렌 AI-DLC 공정별 에이전트 스킬 정의 레포.

모든 에이전트 스킬은 이 레포에서 단일 관리됩니다.
Claude Code는 `~/.claude/agents/` 심볼릭 링크를 통해 에이전트를 호출합니다.

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

---

## 구조

```
product-agents/
├── 01-inception/
│   ├── requirements-analyst.md    # 요구사항 분석
│   ├── application-designer.md    # 컴포넌트 설계
│   └── cross-domain-checker.md    # 크로스-도메인 참조 검증
├── 02-spec/
│   ├── units-generator.md         # 유닛 분해
│   └── spec-writer.md             # 유닛별 스펙 확정
├── 03-plan/
│   ├── code-planner.md            # wiki 기반 구현 계획
│   └── functional-designer.md     # 비즈니스 로직 상세 설계
├── 04-build/
│   └── debugger.md                # 에러 진단 및 수정 방향
├── 05-test/
│   └── tester.md                  # 테스트 전략 및 작성
├── 06-review/
│   ├── kotlin-reviewer.md         # Kotlin/Spring Boot 코드 리뷰
│   ├── typescript-reviewer.md     # TypeScript/React 코드 리뷰
│   └── code-simplifier.md         # 복잡도 제거
├── 07-ship/
│   └── ship-checklist.md          # 배포 전 게이트 체크
├── 08-operations/
│   └── incident-analyzer.md       # Sentry 장애 분석
├── services/                      # 서비스별 레포 → 공정별 에이전트 매핑
│   ├── gongbiz-crm-b2b.md
│   ├── gongbiz-b2c.md
│   ├── instaget.md
│   └── fineadple.md
├── registry.yaml                  # 전체 에이전트 목록
└── setup.sh                       # 심볼릭 링크 설치 스크립트
```

---

## 설치

최초 설정 시 1회 실행합니다.

```bash
git clone https://github.com/herren-official/product-agents.git ~/git/product-agents
~/git/product-agents/setup.sh
```

이후 에이전트 업데이트는 `git pull`만으로 자동 반영됩니다 (심볼릭 링크이므로 재실행 불필요).

새 에이전트가 추가된 경우 `setup.sh`를 다시 실행합니다.

---

## 동작 방식

```
product-agents/06-review/kotlin-reviewer.md   (소스 - Git 관리)
        ↑ 심볼릭 링크
~/.claude/agents/kotlin-reviewer.md           (Claude Code가 읽는 위치)
```

`setup.sh`가 `01-inception/` ~ `08-operations/` 하위 `.md` 파일을
`~/.claude/agents/`에 flat 심볼릭 링크로 연결합니다.

---

## 서비스별 에이전트 매핑

각 서비스 레포에서 작업 시작 시 `services/<service-name>.md`를 먼저 확인합니다.
현재 공정에 해당하는 에이전트를 `~/.claude/agents/`에서 호출합니다.

| 서비스 | 매핑 파일 |
|--------|----------|
| gongbiz-crm-b2b | `services/gongbiz-crm-b2b.md` |
| gongbiz-b2c | `services/gongbiz-b2c.md` |
| instaget | `services/instaget.md` |
| fineadple | `services/fineadple.md` |

---

## 에이전트 추가

1. 해당 공정 디렉토리(`01`~`08`)에 `<agent-name>.md` 작성
2. `registry.yaml`에 항목 추가
3. `./setup.sh` 실행 → 심볼릭 링크 갱신
4. 관련 `services/*.md` 테이블에 에이전트 등록
5. PR 머지 → 각 환경에서 `git pull`

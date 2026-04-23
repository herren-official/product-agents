# product-agents

헤렌 AI-DLC 공정별 에이전트 스킬 정의 레포.

모든 에이전트 스킬은 이 레포에서 단일 관리됩니다.
Claude Code는 `~/.claude/agents/` 심볼릭 링크를 통해 에이전트를 호출합니다.

---

## 구조

```
product-agents/
├── inception/              # AI-DLC Inception 공정 에이전트
│   ├── requirements-analyst.md    # 요구사항 분석
│   ├── application-designer.md    # 컴포넌트 설계
│   ├── units-generator.md         # 유닛 분해
│   └── cross-domain-checker.md    # 크로스-도메인 참조 검증
├── construction/           # AI-DLC Construction 공정 에이전트
│   ├── functional-designer.md     # 비즈니스 로직 상세 설계
│   ├── kotlin-reviewer.md         # Kotlin/Spring Boot 코드 리뷰
│   └── typescript-reviewer.md     # TypeScript/React 코드 리뷰
├── operations/             # AI-DLC Operations 공정 에이전트 (예정)
├── registry.yaml           # agent-hub 연동용 에이전트 목록
└── setup.sh               # 심볼릭 링크 설치 스크립트
```

---

## 설치

맥미니 또는 로컬 개발 환경 최초 설정 시 1회 실행합니다.

```bash
git clone https://github.com/herren-official/product-agents.git ~/git/product-agents
~/git/product-agents/setup.sh
```

이후 에이전트 업데이트는 `git pull`만으로 자동 반영됩니다 (심볼릭 링크이므로 재실행 불필요).

---

## 동작 방식

```
product-agents/construction/kotlin-reviewer.md   (소스 - Git 관리)
        ↑ 심볼릭 링크
~/.claude/agents/kotlin-reviewer.md              (Claude Code가 읽는 위치)
```

`setup.sh`가 `inception/`, `construction/`, `operations/` 하위 `.md` 파일을
`~/.claude/agents/`에 flat 심볼릭 링크로 연결합니다.

---

## 에이전트 추가

1. 해당 공정 디렉토리에 `.md` 파일 작성
2. `registry.yaml`에 등록
3. PR 머지 → 각 환경에서 `git pull`

새 환경에서 링크 재생성이 필요한 경우 `setup.sh`를 다시 실행합니다.

---

## AI-DLC 공정 흐름

```
요구사항 발생
    ↓
[Inception]
  requirements-analyst   → 요구사항 정제 + outcome_metric 확인
  application-designer   → 컴포넌트 설계 + API 목록
  cross-domain-checker   → 크로스-도메인 영향도 분석
  units-generator        → 플랫폼별 유닛 분해 → Linear 이슈 생성
    ↓
[디자인] Figma 완성 → 플랫폼별 구현 스펙 첨부
    ↓
[Construction]
  functional-designer    → 유닛별 비즈니스 로직 설계
  kotlin-reviewer        → Kotlin/Spring Boot 코드 리뷰
  typescript-reviewer    → TypeScript/React 코드 리뷰
    ↓
[Operations] (예정)
  테스트 → 배포
```

---

## 대상 서비스 및 레포

| 서비스 | 레포 | 플랫폼 | Construction 에이전트 |
|--------|------|--------|----------------------|
| gongbiz-crm-b2b | gongbiz-crm-b2b-backend | Kotlin/Spring | kotlin-reviewer |
| | gongbiz-crm-b2b-front | TypeScript/React | typescript-reviewer |
| | gongbiz-crm-b2b-web | Next.js | typescript-reviewer |
| | gongbiz-crm-android | Kotlin/Android | kotlin-reviewer |
| | gongbiz-crm-iOS | Swift | *(레포 내 에이전트 12개)* |
| gongbiz-b2c | gongbiz-b2c-frontend | TypeScript/React | *(레포 내 컨벤션 11개)* |
| | gongbiz-b2c-android | Kotlin/Android | *(레포 내 에이전트 4개)* |
| | gongbiz-b2c-iOS | Swift | *(레포 내 에이전트 10개)* |
| instaget | instaget-server | Kotlin/Spring | kotlin-reviewer |
| | instaget-b2c-frontend | TypeScript/React | typescript-reviewer |
| fineadple | fineadple-server | Kotlin/Spring | kotlin-reviewer |
| | fineadple-b2c-frontend | TypeScript/React | typescript-reviewer |

> 레포 내 에이전트/컨벤션이 충분한 경우 전역 에이전트 불필요.
> Inception 공정(requirements-analyst, cross-domain-checker)은 모든 레포에 공통 적용.

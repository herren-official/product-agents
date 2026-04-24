# TODO

AI-DLC 개선 및 통합 관련 백로그.

---

## 🔍 검토 중

### claude-task-master 연동
- **레포**: https://github.com/eyaltoledano/claude-task-master
- **포지션**: AI-DLC 앞단의 작업 관리 레이어 (product-agents와 충돌 없음)
- **흐름**:
  ```
  Hamster Studio에서 Brief(PRD) 등록
    → task-master가 작업 트리로 자동 분해
    → task-master start → Claude Code 실행
    → CLAUDE.md 로드 → services/*.md 참조
    → 02-spec: units-generator → spec-writer
    → 03-plan: code-planner → functional-designer
  ```
- **검증 방법**: `npx task-master init`을 instaget-server 또는 gongbiz-crm-b2b-backend에서 시범 실행
- **판단 기준**: Brief → 작업 분해 품질이 units-generator 수준인가?

---

## 🏗️ 에이전트 보강

### 03-plan
- [ ] `architect.md` — 신규 서비스 전체 아키텍처 설계 (모놀리스 → 마이크로서비스 전환 등 대규모 변경 대응)

### 04-build
- [ ] `migration-planner.md` — DB 마이그레이션 스크립트 설계 + 롤백 전략

### 05-test
- [ ] `e2e-planner.md` — Playwright E2E 시나리오 설계 (핵심 흐름 기준)

---

## 📋 서비스 매핑 보완

- [ ] `services/gongbiz-b2c.md` — 03-plan 에이전트 미비 (Kotlin 백엔드 레포 추가 예정)

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
    → construction 공정: code-planner → kotlin-reviewer
  ```
- **검증 방법**: `npx task-master init`을 instaget-server 또는 gongbiz-crm-b2b-backend 에서 시범 실행
- **판단 기준**: Brief → 작업 분해 품질이 units-generator 수준인가?

---

## 🏗️ 에이전트 보강

### 02-construction
- [ ] `debugger.md` — 에러 메시지 → wiki 탐색 → 원인 진단 → 수정 → 검증 (Cline debugging 패턴)

### 03-operations (현재 비어있음)
- [ ] `incident-analyzer.md` — Sentry 에러 → 관련 코드 탐색 → 원인 분석 → 핫픽스 범위 파악

---

## 📋 서비스 매핑 보완

- [ ] `services/gongbiz-b2c.md` — construction 에이전트 미비 (현재 inception만 있음)
- [ ] `services/fineadple.md` — construction 에이전트 미비

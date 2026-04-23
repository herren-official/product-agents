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
- [ ] `incident-analyzer.md` — Sentry 이슈 대응 에이전트
  - **플로우**:
    ```
    Sentry 이슈 URL 또는 에러 본문 입력
      → 에러 타입 / 스택트레이스 파싱
      → wiki 탐색: 관련 클래스/모듈 식별
      → 소스 드릴다운: 실제 코드 확인 (최소한)
      → 원인 가설 도출 (재현 조건 포함)
      → 영향 범위: 동일 패턴 다른 경로 존재 여부
      → 대응 방안: 핫픽스 범위 + 체크리스트 출력
    ```
  - **출력물**: 원인 분석 + 수정 대상 파일/라인 + 재발 방지 체크리스트

---

## 📋 서비스 매핑 보완

- [ ] `services/gongbiz-b2c.md` — construction 에이전트 미비 (현재 inception만 있음)
- [ ] `services/fineadple.md` — construction 에이전트 미비

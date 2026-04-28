# {epic-project-name} — 프로젝트 컨텍스트 (개요)

> 생성 일자: {YYYY-MM-DD}
> 에픽 번호: {GBIZ-XXXXX 또는 "없음"}
> 생성자: `/project-kickoff {epic-project-name}`

> 📌 **이 문서는 얇은 개요**다. 설계 초안은 [design-draft.md](./design-draft.md) 참조.
> - `context.md` (이 문서) — 프로젝트 전체 컨텍스트의 **네비게이션 허브**. 팀 공유용.
> - `design-draft.md` — 데이터 모델/API/Phase 분할/설계 결정이 담긴 **설계 문서 초안**. 엔지니어가 이어서 다듬음.

---

## 1. 프로젝트 개요

- **목표**: {1~2줄. 노션 정책 페이지에서 추출}
- **범위**: {무엇을 포함하고 무엇을 제외하는지}
- **기대 효과**: {KPI, 성공 지표}
- **배포 타겟 모듈**: {gongbiz-crm-b2b-api / gongbiz-crm-b2b-backend / ...}
- **마감/제약**: {freeze 기간, 릴리즈 일정 등}

---

## 2. 정책/요구사항 요약

### 2.1 기능 요구사항
- {항목 1}
- {항목 2}

### 2.2 비기능 요구사항
- 성능: {QPS, 응답시간 등 명시 있으면}
- 보안/컴플라이언스: {PII, 감사 로그 등}
- 호환성: {기존 API 영향 여부}

### 2.3 이해관계자
- PM: {이름/핸들}
- 디자이너: {이름/핸들}
- 백엔드: {이름/핸들}
- 프런트엔드: {이름/핸들}
- QA: {이름/핸들}

> 상세: [policy-summary.md](./policy-summary.md)

---

## 3. 디자인 요약

- 화면 수: {N}
- 주요 플로우: {3~5개 bullet}
- 새 컴포넌트 필요: {목록}
- UI 상태 (빈/에러/로딩): {처리 지점}

> 상세: [design-notes.md](./design-notes.md)

---

## 4. 데이터 모델

### 영향받는 테이블
| 테이블 | 변경 예상 | 비고 |
|---|---|---|
| {table_a} | 컬럼 추가 | {메모} |
| {table_b} | 신규 | {메모} |

### 신규 테이블 필요 여부
- {예 / 아니오 + 이유}

> 상세: [db-schema.md](./db-schema.md)

---

## 5. 영향받는 코드

### 주요 엔트리포인트
- `{path/to/Controller.kt}:{line}` — {설명}
- `{path/to/Service.kt}:{line}` — {설명}

### 재사용 가능한 패턴
- {기존 유사 기능 경로 + 참고 포인트}

### 신규로 만들어야 할 영역
- {Controller / Service / Repository / Domain 어디인지}

> 상세: [codebase-map.md](./codebase-map.md)

---

## 6. 인프라 맵

### CloudWatch 로그 그룹
- {로그 그룹명} — {용도}

### Lambda
- {함수명} — {용도}

### SQS/Kafka
- {큐/토픽명} — {용도}

### 추가 필요 리소스
- {신규 로그 그룹, 알람 등}

> 상세: [infra-map.md](./infra-map.md)

---

## 7. 리스크 / 미결정 사항

| # | 항목 | 차단 여부 | 결정 주체 | 상태 |
|---|---|---|---|---|
| 1 | {예: 배치 주기 5분 vs 10분} | Blocker | PM | 미결정 |
| 2 | {예: 신규 테이블 FK 방향} | 비차단 | BE | 미결정 |

---

## 8. Slack/의사결정 히스토리

- {주요 결정 + 출처 링크}

> 상세: [slack-notes.md](./slack-notes.md) (수집된 경우)

---

## 9. 추천 에이전트 팀

> 상세: [agent-team.md](./agent-team.md)

- {핵심 에이전트 3개 요약}

---

## 10. 다음 단계 제안

1. `context.md`를 팀과 함께 검토 (특히 7번 미결정 사항 해결).
2. [design-draft.md](./design-draft.md)의 **[수동 검토 필요]** 섹션을 엔지니어가 채움 (설계 결정, Phase 분할, API 상세).
3. `architect` 에이전트로 설계 초안 검토 → `critic`로 누락/리스크 재검증.
4. `/plan "{한 줄 요약}"`으로 구현 계획 수립.
5. 브랜치 생성 — 네이밍: `GBIZ-XXXXX-{slug}` (`/create-br` 또는 `/create-branch` 활용).
6. 구현 후 `/api-test-plan {branch}`로 QA 플랜 생성.
7. 배포 후 `/monitor {env} .claude/plan/{plan}.md`로 운영 모니터링.

---

## 출처

- 노션: {URLs}
- 피그마: {URL or 이미지 경로}
- Slack: {URLs}
- 유사 기능 참고: {경로/PR URLs}
---
name: b2b-backend-plan-update
description: |
  모니터링 결과를 테스트 플랜의 QA 결과 요약 테이블에 반영한다.
  다음 상황에서 사용할 것:
  - /monitor 종료 후 QA 결과를 플랜에 기록할 때
  - Phase별 OK/NOK 결과를 플랜 md에 업데이트할 때
  다음 상황에서는 사용하지 않을 것:
  - 테스트 플랜을 새로 생성할 때 (/api-test-plan 커맨드 사용)
  - 모니터링을 실행할 때 (/monitor 커맨드 사용)
allowed-tools: Read, Write, Glob
user-invocable: true
---

$ARGUMENTS 에서 플랜 파일 경로를 받아 QA 결과를 업데이트한다.

## 입력 파싱
`$ARGUMENTS`에서 플랜 md 파일 경로를 추출한다.
비어있으면 `.claude/plan/` 디렉토리에서 가장 최근 `*-test-plan.md` 파일을 사용한다.

## 결과 수집
1. 플랜 md를 읽어 Phase 목록(P1, P2, ..., E1, E2, ...)을 추출한다.
2. `~/monitor-logs/` 디렉토리에서 가장 최근 날짜 폴더의 수집된 로그 파일을 확인한다.
3. 사용자에게 각 Phase의 결과를 질문한다:

```
## QA 결과 입력
각 Phase의 결과를 알려주세요 (OK / NOK / 미테스트).
NOK인 경우 비고를 함께 입력해주세요.

| Phase | 제목 | 결과 | 비고 |
|-------|------|------|------|
| P1 | {제목} | ? | |
| P2 | {제목} | ? | |
| E1 | {제목} | ? | |
```

## 플랜 업데이트
사용자의 응답을 받아 플랜 md의 "QA 결과 요약" 테이블을 업데이트한다.

### Phase별 결과 체크박스 업데이트
각 Phase 섹션의 `- **결과**: [ ] OK / [ ] NOK` 항목도 함께 업데이트한다.
- OK: `- **결과**: [x] OK`
- NOK: `- **결과**: [x] NOK — {비고}`

### QA 결과 요약 테이블 업데이트
```markdown
## QA 결과 요약
| Phase | 결과 | 비고 |
|-------|------|------|
| P1 | OK | - |
| P2 | NOK | {비고 내용} |
| E1 | 미테스트 | - |
```

## 최종 출력
```
## 플랜 업데이트 완료
- 파일: {플랜파일}
- 결과: OK {okCount}건 / NOK {nokCount}건 / 미테스트 {skipCount}건

### NOK Phase 요약
- P2: {비고}

### 다음 단계
- NOK Phase의 원인을 수정한 후 `/monitor {환경} {플랜파일}`로 재모니터링하세요.
- 모든 Phase가 OK이면 QA 완료입니다.
```

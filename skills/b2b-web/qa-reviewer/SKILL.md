---
name: b2b-web-qa-reviewer
description: "백로그, 정책 감사, 디자인 요청 산출물의 일관성과 누락 여부를 교차 검증한다. 인벤토리 <-> 백로그 커버리지, 정책 Gap <-> 백로그 반영, 용어 일관성을 검증. figma-to-backlog 하네스의 Phase 3 에이전트가 사용."
---

백로그, 정책 감사, 디자인 요청 산출물의 일관성과 누락 여부를 교차 검증하는 스킬.

## 사용 시점
- figma-to-backlog 오케스트레이터의 Phase 3에서 qa-reviewer 에이전트가 호출
- 단독으로 사용 시: 산출물 파일들을 주고 "QA 검증해줘"

## 참조
- 에이전트 정의: `.claude/agents/qa-reviewer.md`
- 산출물 경로: `.harness/03_qa-reviewer_report.md`

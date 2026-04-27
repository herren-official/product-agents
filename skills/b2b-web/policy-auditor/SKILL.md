---
name: b2b-web-policy-auditor
description: "디자인의 Empty/Error/Loading state, 반응형, 접근성, 예외 흐름 등 정책 누락을 감사한다. 화면별 5가지 상태 체크, WCAG 2.1 AA 기준 접근성 감사. figma-to-backlog 하네스의 Phase 2 에이전트가 사용."
---

디자인의 정책 누락을 감사하는 스킬. Empty/Error/Loading state, 반응형, 접근성, 예외 흐름을 체크한다.

## 사용 시점
- figma-to-backlog 오케스트레이터의 Phase 2에서 policy-auditor 에이전트가 호출
- 단독으로 사용 시: 인벤토리 파일을 주고 "정책 감사해줘"

## 참조
- 에이전트 정의: `.claude/agents/policy-auditor.md`
- 산출물 경로: `.harness/02_policy-auditor_gaps.md`, `.harness/02_policy-auditor_design-requests.md`

---
name: b2b-web-design-analyzer
description: "Figma MCP로 디자인 데이터를 추출하고, 화면/컴포넌트/인터랙션 인벤토리를 작성한다. Figma URL이 주어지면 디자인 구조를 파악. figma-to-backlog 하네스의 Phase 1 에이전트가 사용."
---

Figma MCP로 디자인 데이터를 추출하고 화면/컴포넌트/인터랙션 인벤토리를 작성하는 스킬.

## 사용 시점
- figma-to-backlog 오케스트레이터의 Phase 1에서 design-analyzer 에이전트가 호출
- 단독으로 사용 시: Figma URL을 주고 "디자인 인벤토리 추출해줘"

## 참조
- 에이전트 정의: `.claude/agents/design-analyzer.md`
- 산출물 경로: `.harness/01_design-analyzer_inventory.md`

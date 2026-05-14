---
name: b2c-android-analyze-module
description: "모듈의 구조, ViewModel, Screen, API 호출을 한눈에 분석. Use when: 모듈 분석, 모듈 구조 파악, 파일 구조 확인, 모듈 설명"
argument-hint: "<module-name> (예: shop-detail, home, payment)"
allowed-tools: ["Agent"]
---

# 모듈 분석

지정된 모듈의 정적 구조 분석을 `analyze-code` 통합 에이전트에 `mode=module` 로 위임. 에이전트가 모듈 전체 grep + Read 후 정리된 표 형식으로 반환하므로 메인 컨텍스트에 raw 코드 노출 없음.

분석 대상: $ARGUMENTS

## 호출

`Agent` 도구 1회:
- `subagent_type`: `analyze-code`
- `description`: `Analyze module $ARGUMENTS`
- `prompt`: `mode=module, target=$ARGUMENTS. B2C Android 모듈 정적 구조 분석. 출력 형식·절차·원칙은 agent 정의 참조.`

출력 형식 / 분석 절차 / 원칙은 에이전트 정의(`.claude/agents/analyze-code.md`) 가 단일 진실 소스. 에이전트 결과를 메인 대화에 그대로 표시.

## 모듈명 규칙
- feature 모듈: `shop-detail`, `home`, `payment`, `around-me` 등
- core 모듈: `data`, `data-api`, `designsystem-v2`, `navigation`, `architecture` 등
- 모듈 인덱스는 [.docs/module-index.md](../../../.docs/module-index.md) 참조

## 후속

분석 결과로 키워드 기반 플로우 추적이 필요하면 `/explain-flow <키워드>` 호출.

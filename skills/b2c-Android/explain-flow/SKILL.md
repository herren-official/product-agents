---
name: b2c-android-explain-flow
description: "키워드로 관련 사용자 플로우를 Screen -> ViewModel -> UseCase -> API까지 추적. Use when: 플로우 설명, 동작 추적, 어떻게 동작하는지, 코드 흐름 파악"
argument-hint: "<keyword> (예: 예약결제, 로그인, 찜하기, 리뷰작성)"
allowed-tools: ["Agent"]
---

# 사용자 플로우 추적

키워드 관련 전체 데이터 흐름 추적을 `analyze-code` 통합 에이전트에 `mode=flow` 로 위임. 에이전트가 feature ↔ core:domain ↔ core:data 경계를 가로지르는 grep + Read 후 정리된 단계로 반환하므로 메인 컨텍스트에 raw 코드 노출 없음.

키워드: $ARGUMENTS

## 호출

`Agent` 도구 1회:
- `subagent_type`: `analyze-code`
- `description`: `Trace flow for "$ARGUMENTS"`
- `prompt`: `mode=flow, target=$ARGUMENTS. B2C Android 키워드 관련 사용자 플로우 Top-Down 추적. 출력 형식·절차·원칙은 agent 정의 참조.`

출력 형식 / 분석 절차 / 원칙은 에이전트 정의(`.claude/agents/analyze-code.md`) 가 단일 진실 소스. 에이전트 결과를 메인 대화에 그대로 표시.

## 키워드 팁
- 한국어 자연어 OK: `예약결제`, `리뷰작성`, `찜하기`
- 영문 식별자도 OK: `favorite`, `payment`, `signin`
- 에이전트가 한국어 → 영문 함수명 변환도 시도함 (예: 찜하기 → favorite / wishlist)

## 후속

특정 모듈 구조를 더 자세히 보려면 `/analyze-module <모듈명>` 호출.

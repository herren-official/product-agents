---
name: b2c-android-explain-flow
description: "키워드로 관련 사용자 플로우를 Screen -> ViewModel -> UseCase -> API까지 추적. Use when: 플로우 설명, 동작 추적, 어떻게 동작하는지, 코드 흐름 파악"
argument-hint: "<keyword> (예: 예약결제, 로그인, 찜하기, 리뷰작성)"
---

# 사용자 플로우 추적

키워드와 관련된 전체 데이터 흐름을 추적하여 설명합니다.

키워드: $ARGUMENTS

## 분석 순서

### 1. 키워드로 관련 코드 검색
- Screen, ViewModel, UseCase, Repository에서 관련 함수/클래스 검색
- PRD 문서(`.docs/prd/`)에서 관련 비즈니스 로직 참조

### 2. 사용자 플로우 추적 (Top-Down)

**UI 계층**: 어떤 화면에서, 어떤 액션으로 트리거, 어떤 UI 상태 변화
**ViewModel 계층**: public 메서드, apiFlow/slackFlow, reduceSuccessState, postSideEffect
**Domain 계층**: UseCase, Repository combine, 데이터 변환
**Data 계층**: Retrofit 엔드포인트, Request/Response, 에러 처리

### 3. 분기 조건 / 에러 시나리오 정리

## 출력 형식
```
## "{키워드}" 플로우 분석

### 전체 흐름
{Screen} → {ViewModel.method()} → {UseCase} → {Repository} → API

### 상세 단계
1. **사용자 액션**: 파일, 호출
2. **ViewModel 처리**: API 호출, 상태 업데이트
3. **UseCase 로직**: Repository 호출, 데이터 조합
4. **API 호출**: 엔드포인트, Request/Response

### 분기 조건 / 에러 처리 / 관련 파일 목록
```

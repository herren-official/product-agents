---
name: b2c-android-analyze-module
description: "모듈의 구조, ViewModel, Screen, API 호출을 한눈에 분석. Use when: 모듈 분석, 모듈 구조 파악, 파일 구조 확인, 모듈 설명"
argument-hint: "<module-name> (예: shop-detail, home, payment)"
---

# 모듈 분석

지정된 모듈의 구조를 분석하여 빠르게 파악할 수 있도록 정리합니다.

분석 대상: $ARGUMENTS

## 분석 순서

### 1. 모듈 위치 확인
- `feature/$ARGUMENTS/` 또는 `core/$ARGUMENTS/` 경로에서 소스 파일 탐색
- `build.gradle.kts`에서 의존성 확인

### 2. 파일 구조 분석
- 전체 Kotlin 파일 목록 (src/main)
- Screen, ViewModel, Contract, Navigation, Component 분류

### 3. ViewModel 분석 (핵심)
- `BaseIntentViewModel` 상속 확인
- `init {}` 블록, public 메서드, `apiFlow`/`slackFlow`, `reduceSuccessState`, `postSideEffect`

### 4. UiState / Screen / Navigation / 테스트 현황 분석

## 출력 형식
```
## {모듈명} 모듈 분석

### 파일 구조 ({N}개 파일)
### ViewModel 요약 (표)
### UiState 필드 (표)
### 네비게이션 맵
### API 호출 목록 (표)
### 테스트 현황
```

## PRD 연동
- `.docs/prd/{module-name}.md` 파일이 존재하면 비즈니스 로직 참고

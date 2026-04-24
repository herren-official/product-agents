---
name: b2c-ios-pre-pr-review
description: "PR 생성 전 브랜치 전체 변경사항을 종합 리뷰합니다"
argument-hint: "[검사 옵션]"
disable-model-invocation: false
allowed-tools: ["Read", "Grep", "Glob", "Bash"]
---

# Pre-PR Review

PR 생성 직전에 실행되는 브랜치 전체 종합 리뷰 스킬입니다.

## 실행 알림
이 스킬이 실행되면 가장 먼저 "[pre-pr-review] 스킬이 실행되었습니다."를 출력할 것

$ARGUMENTS

## 0. 현재 상태 (동적 주입)

### 현재 브랜치
!`git branch --show-current`

### GBIZ 번호
!`git branch --show-current | grep -oE "GBIZ-[0-9]+" | head -1 || echo "GBIZ 번호 없음"`

### 베이스 브랜치 자동 감지
!`CURRENT=$(git branch --show-current) && CREATED_FROM=$(git reflog show "$CURRENT" 2>/dev/null | grep "branch: Created from" | head -1 | sed 's/.*Created from //') && echo "분기 원본: $CREATED_FROM" || echo "감지 실패 - develop 사용"`

### 변경된 파일 목록
!`BASE=$(git reflog show "$(git branch --show-current)" 2>/dev/null | grep "branch: Created from" | head -1 | sed 's/.*Created from //' || echo "origin/develop") && git diff "$BASE"...HEAD --name-status 2>/dev/null || git diff origin/develop...HEAD --name-status 2>/dev/null || echo "비교 불가"`

## 검사 프로세스

### 1단계: 변경 파일 수집 및 분류

동적 주입된 변경 파일 목록을 기반으로 분류한다:

- **레이어별 분류**: Feature, View, Domain(UseCase/Model), Network(Router/Repository/DTO), Test, Docs, 기타
- **변경 유형별 분류**: 신규(A), 수정(M), 삭제(D), 이름변경(R)
- Swift 파일만 코드 검사 대상으로 선별

### 2단계: 코드 품질 검사

변경된 Swift 파일을 Read 도구로 읽고 다음 항목을 검사한다:

| 검사 항목 | 심각도 | 설명 |
|----------|--------|------|
| 하드코딩된 색상/폰트/간격 | 에러 | DesignSystem 토큰 미사용 (hex 코드, 직접 Font 지정 등) |
| 매직 넘버/문자열 | 경고 | 의미 없는 숫자/문자열 리터럴 직접 사용 |
| 불필요한 import | 경고 | 사용되지 않는 import 문 |
| 접근제어자 누락 | 경고 | 다른 모듈에서 접근 필요한 곳에 internal(기본값) 사용 |
| 네이밍 비일관성 | 경고 | 파일 간 동일 개념에 다른 이름 사용 |

> DesignSystem 토큰 확인 시 `.docs/conventions/DESIGN_SYSTEM.md` 참조

### 3단계: 구조 검사

| 검사 항목 | 심각도 | 설명 |
|----------|--------|------|
| TCA Feature 구조 | 에러 | State/Action/Reducer/body 템플릿 미준수 |
| View 파일 구조 | 경고 | body/Subviews/MARK 섹션 구조 미준수 |
| 파일 위치 | 경고 | PROJECT_STRUCTURE.md 규칙과 불일치 |
| 새 파일 디렉토리 | 경고 | 올바른 디렉토리에 위치하지 않음 |

> 구조 검사 시 `.docs/conventions/CONVENTIONS.md` 및 `.docs/PROJECT_STRUCTURE.md` 참조

### 4단계: 완성도 검사

| 검사 항목 | 심각도 | 설명 |
|----------|--------|------|
| Feature 테스트 누락 | 참고 | 새 Feature에 대응하는 테스트 파일 미존재 |
| MockData 누락 | 참고 | 새 Router 추가 시 MockData JSON 미존재 |
| MockRouter 누락 | 참고 | 새 Repository 추가 시 MockRouter 미존재 |
| 문서 업데이트 필요 | 참고 | 네트워크 레이어 변경 시 NETWORK_SYSTEM.md 업데이트 필요 여부 |

### 5단계: 결과 보고

다음 형식으로 보고:

```
### Pre-PR Review 결과

[에러] N건 (PR 전 수정 필수)
1. path/to/File.swift:42 - 하드코딩된 색상 #4E3BFF -> .brand_300 사용
2. path/to/Feature.swift - TCA 구조 미준수: Reducer body 누락

[경고] N건 (권장 수정)
1. path/to/File.swift:15 - 불필요한 import Foundation
2. path/to/View.swift:80 - 매직 넘버 16 -> 상수 추출 권장

[참고] N건
1. NewFeature에 대한 테스트 파일 미발견 (권장: Tests/Feature/NewFeatureTests.swift)
2. NewRouter 추가 - MockData JSON 파일 확인 필요

수정하시겠습니까? [Y] 수정 / [S] 건너뛰고 PR 진행 / [N] 취소
```

## 사용자 응답 처리

- **Y (수정)**: 발견된 항목을 수정하고 재검사
- **S (건너뛰기)**: 검사 결과를 무시하고 PR 생성 단계로 진행
- **N (취소)**: PR 생성 중단

## 에러 처리

| 에러 | 대응 |
|------|------|
| 베이스 브랜치 비교 불가 | develop 브랜치 기준으로 fallback |
| 파일 읽기 실패 | 해당 파일을 "검사 불가"로 보고하고 계속 진행 |
| DesignSystem 토큰 매핑 불가 | DESIGN_SYSTEM.md 문서 참조 권고 |

## 참조 문서

- 코딩 컨벤션: `.docs/conventions/CONVENTIONS.md`
- DesignSystem: `.docs/conventions/DESIGN_SYSTEM.md`
- 프로젝트 구조: `.docs/PROJECT_STRUCTURE.md`
- 네트워크 시스템: `.docs/conventions/NETWORK_SYSTEM.md`

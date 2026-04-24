---
name: b2c-android-test-setup
description: "테스트할 ViewModel 선정 -> 노션 문서 복제 -> 브랜치 생성까지 한번에. Use when: 테스트 준비, 테스트 셋업, 테스트 작업 시작"
argument-hint: "[ViewModel명] (생략 시 자동 선정)"
allowed-tools: ["bash", "read", "grep", "glob", "mcp__notionMCP__search", "mcp__notionMCP__fetch", "mcp__notionMCP__duplicate-page", "mcp__notionMCP__notion-update-page"]
---

# 테스트 작업 준비

테스트 작업을 위한 노션 문서를 복제하고 작업용 브랜치를 생성합니다.

!git branch --show-current
!git status --porcelain

## 동작 순서

### 1. ViewModel 선정
- 인자 있으면 해당 ViewModel, 없으면 `.docs/viewmodel-test-status.md`에서 자동 선정

### 2. 노션 문서 생성
- 최근 테스트 문서 검색 → `mcp__notionMCP__duplicate-page`로 복제
- 제목: `[B2C][Android] {ViewModel명} 테스트 코드 작성`, 상태: "할 일"

### 3. Git 브랜치 생성
- 형식: `test/GBIZ-{ID}-{viewmodel-name}-test`

### 4. 결과 안내
- 노션 문서 링크, 브랜치명, 다음 단계 (`/unit-test`) 안내

## 참고 문서
- `.docs/test-workflow.md`, `.docs/notion-convention.md`, `.docs/branch-convention.md`

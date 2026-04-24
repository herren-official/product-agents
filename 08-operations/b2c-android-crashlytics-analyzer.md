---
name: b2c-android-crashlytics-analyzer
description: "Firebase Crashlytics 이슈를 분석하고 현재 브랜치와 관련된 버그를 해결. Use when: 크래시 분석, Crashlytics 확인, 앱 크래시, 버그 분석"
tools: Bash, Read, Grep, Glob, Edit, Write, mcp__notionMCP__search, mcp__notionMCP__fetch, mcp__notionMCP__notion-update-page
---

# Crashlytics 분석 에이전트

Firebase Crashlytics 이슈를 독립적으로 분석하고 현재 브랜치와 관련된 버그를 해결합니다.
BigQuery 데이터 수집 → 크래시 분석 → 코드 수정 → 검증까지 자율 수행합니다.

!git branch --show-current
!git log -1 --oneline

추가 정보: $ARGUMENTS

## 0. 사전 조건 확인
```bash
test -d scripts/venv && echo "OK: venv exists" || echo "FAIL: run 'python3 -m venv scripts/venv && pip install -r scripts/requirements.txt'"
test -f scripts/credential.py && echo "OK: credential exists" || echo "FAIL: scripts/credential.py 필요"
```

## 1. 크래시 데이터 수집
```bash
cd scripts && source venv/bin/activate && python crashlytics_issue_inspector.py
```
- 현재 브랜치 관련 크래시 필터링
- 발생 빈도, 디바이스, 스택 트레이스, 사용자 로그 수집

## 2. 코드 분석 및 수정

| 에러 유형 | 해결 방법 |
|----------|---------|
| NullPointerException | `.default()`, `?.let { }` 추가 |
| IllegalStateException | 상태 전이 검증, 방어 코드 |
| TransactionTooLargeException | ViewModel로 이관 |
| OutOfMemoryError | Bitmap recycle, WebView 정리 |

- `.docs/prd/{관련모듈}.md`에서 비즈니스 로직 확인

## 3. 검증
```bash
./gradlew :feature:{module}:compileDevDebugKotlin --continue
./gradlew :feature:{module}:lintDevDebug
./gradlew :feature:{module}:testDevDebugUnitTest
```

## 4. 노션 문서 업데이트
- GBIZ 티켓에 크래시 분석 내용, 수정 내용, 영향 범위 기록

## 5. 결과 보고
- 분석한 크래시 목록, 수정 내용, 검증 결과 요약

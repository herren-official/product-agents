---
name: crm-ios-branch-creator
description: Git 브랜치를 생성합니다. GBIZ 번호나 노션 링크를 받아 브랜치 네이밍 규칙에 맞는 브랜치를 생성합니다. 브랜치 생성, 브랜치 만들어줘 요청 시 사용.
allowed-tools: Bash, Read, mcp__notionMCP__notion-fetch
---

# Branch Creator

Git 브랜치를 생성하는 스킬입니다.

## 실행 알림
이 스킬이 실행되면 가장 먼저 "[crm-ios-branch-creator] 스킬이 실행되었습니다."를 출력할 것

## 실행 프로세스

### 1단계: 정보 수집

사용자로부터 다음 정보 확인:
- **GBIZ 번호** 또는 **노션 링크**
- **작업 내용** (간단한 설명)

### 2단계: GBIZ 번호 확인

노션 링크가 주어진 경우:
1. `mcp__notionMCP__notion-fetch`로 페이지 정보 가져오기
2. properties의 `userDefined:ID` 필드에서 GBIZ 번호 추출

**주의**: 노션 URL의 마지막 ID는 페이지 ID이며, GBIZ 번호가 아닙니다!

### 3단계: 에픽 여부 판단 (현재 브랜치 기준)

```bash
git branch --show-current
```

**판단 로직:**
- 현재 브랜치가 `{에픽명}/Epic` 또는 `{에픽명}/GBIZ-*` 패턴 → 에픽 브랜치
- 현재 브랜치가 `develop` 또는 사용자가 명시적으로 develop 요청 → 일반 브랜치

### 4단계: 브랜치명 생성

```
# 에픽 브랜치인 경우 (현재: NaverPay/Epic 또는 NaverPay/GBIZ-*)
{에픽명}/GBIZ-{번호}-{작업내용}
예: NaverPay/GBIZ-19375-Payment-Detail-View

# 일반 브랜치인 경우 (현재: develop)
GBIZ-{번호}-{작업내용}
예: GBIZ-12345-Fix-Save-Error
```

**작업내용 규칙:**
- 영문 사용
- 단어는 하이픈(-) 또는 카멜케이스로 연결
- 간결하게 작성

### 5단계: 노션 일감 상태 업데이트

노션 링크가 주어진 경우, 브랜치 생성 전에 일감 속성을 업데이트합니다:

1. **상태 변경**: 백로그/할 일 → "작업 중"
2. **스프린트 설정**: 현재 스프린트를 자동으로 조회하여 설정
   - 스프린트 DB: `collection://46bae361-b009-4ac3-b08e-db4dce33a941`
   - 조회 조건: `스프린트 상태 = "현재"` 인 항목
   - 설정 방법: `mcp__notionMCP__notion-update-page`로 `스프린트: ["https://www.notion.so/{스프린트 페이지 ID}"]` 설정

```
# 상태 업데이트
update-page: properties: {"상태": "작업 중"}

# 스프린트 설정 (현재 스프린트 URL 사용)
update-page: properties: {"스프린트": "[\"https://www.notion.so/{스프린트ID}\"]"}
```

### 6단계: 브랜치 생성

```bash
# 에픽 브랜치에서 생성하는 경우
git checkout -b {에픽명}/GBIZ-{번호}-{작업내용}

# develop에서 생성하는 경우
git checkout develop
git pull origin develop
git checkout -b GBIZ-{번호}-{작업내용}
```

### 7단계: 완료 보고

```
"[호칭], 브랜치를 생성했습니다.
- 브랜치명: {브랜치명}
- 기준 브랜치: {현재 브랜치}
- GBIZ: {GBIZ번호}"
```

## 참조 문서

- Git 가이드: `.docs/GIT_GUIDE.md`
- 호칭: `CLAUDE.local.md`

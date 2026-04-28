---
name: b2b-backend-impact-tracer
description: 특정 enum/상수/인터페이스의 전체 사용처를 빠짐없이 추적하고, 모듈별 영향 범위를 재현 가능하게 산출하는 스킬. 코드체커(code-feasibility-checker)가 핵심 클래스의 영향도 분석 시 사용한다.
---

# 영향도 추적 (impact-tracer)

## 역할

특정 enum, 상수, 인터페이스의 전체 사용처를 프로젝트 전체에서 추적한다. 동일 입력에 대해 동일 결과를 보장하는 재현 가능한 추적을 수행한다.

## 입력

- **대상 클래스명**: 예) `AlimTalkSettingKind`, `SmsMessageType`
- **프로젝트 루트**: 절대 경로
- **(선택) 저장 경로**: 결과를 파일로 저장할 경로

## 출력

- 모듈별 참조 목록 + 총 영향 모듈 수 (markdown 형식)
- 파일 저장 경로가 주어지면 해당 경로에 저장

## 워크플로우

### Step 1: 전체 프로젝트 검색

1. Grep 도구로 전체 프로젝트 검색:
   - **패턴**: 대상 클래스명 (예: `AlimTalkSettingKind`)
   - **제외 경로**: `build/`, `out/`, `.gradle/`, `node_modules/`, `.git/`
   - **모드**: `files_with_matches` (파일 목록만)
2. 검색 결과를 알파벳순 정렬

### Step 2: 카테고리별 분류

각 파일에 대해 Grep (`output_mode: content`)으로 매칭 라인을 확인:

| 카테고리 | 판별 기준 | 예시 |
|---------|---------|------|
| **정의** | `class`, `enum`, `interface`, `object` 키워드 + 대상명 | `enum class AlimTalkSettingKind` |
| **import** | `import` 키워드 + 대상명 | `import ...AlimTalkSettingKind` |
| **직접 참조** | 위 두 가지가 아닌 경우 | `AlimTalkSettingKind.BOOKING_CONFIRMED` |
| **문자열 참조** | `.yml`, `.xml`, `.properties` 파일 | `kind: BOOKING_CONFIRMED` |

### Step 3: enum value 개별 검색 (enum인 경우)

1. 정의 파일에서 enum value 목록 추출
   - 예: `BOOKING_CONFIRMED`, `BOOKING_CANCELED`, ...
2. 특수한 value (비표준 사용되는 것)에 대해 개별 Grep
3. enum value가 문자열로 설정 파일에 사용되는 경우 포착

### Step 4: 모듈별 그룹핑

1. 각 파일 경로에서 모듈명 추출:
   - `gongbiz-notification/src/main/...` → `gongbiz-notification`
   - `gongbiz-crm-b2b-backend/src/main/...` → `gongbiz-crm-b2b-backend`
2. 모듈별 집계:
   - 파일 수
   - 참조 수 (라인 수)
   - 카테고리별 분포

### Step 5: 결과 작성

```markdown
# 영향도 추적: {대상 클래스명}

## 검색 조건
- 패턴: `{사용된 grep 패턴}`
- 제외: `build/, out/, .gradle/, node_modules/, .git/`
- 프로젝트 루트: `{경로}`
- 분석일: {날짜}

## 요약
- **총 참조 파일**: N개
- **영향 모듈**: N개
- **카테고리**: 정의 N개 / import N개 / 직접참조 N개 / 문자열 N개

## 모듈별 상세

### {모듈명} (파일 N개, 참조 N건)

| 파일 | 카테고리 | 매칭 라인 |
|------|---------|----------|
| `src/main/.../AlimTalkSetting.kt:14` | import | `import ...AlimTalkSettingKind` |
| `src/main/.../ComposeMessageUseCase.kt:45` | 직접참조 | `when (kind) { AlimTalkSettingKind.BOOKING_... }` |

### {다음 모듈} ...
```

## 재현성 보장 규칙

1. **검색 패턴 기록 필수** — 사용한 정확한 Grep 패턴을 산출물에 포함
2. **알파벳순 정렬** — 파일 목록, 모듈 목록 모두 알파벳순
3. **시간 종속 요소 배제** — 파일 수정일 등으로 필터링하지 않음
4. **전수 검색** — `head_limit` 사용하지 않음 (`head_limit: 0`으로 무제한)
5. **결과 검증**: "총 영향 모듈" 수를 모듈별 상세의 모듈 수와 대조

## 에러 처리

| 상황 | 대응 |
|------|------|
| 대상 클래스명 오타 | 검색 결과 0건 → 유사 이름 자동 제안 (Glob으로 탐색) |
| 결과 과다 (100파일+) | 모듈별 요약만 제공, 상세는 상위 5개 모듈만 |
| 테스트 파일 포함 여부 | 기본: 포함. `src/test` 별도 섹션으로 분리 표시 |

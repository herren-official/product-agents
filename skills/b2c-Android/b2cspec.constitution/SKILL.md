---
name: b2c-android-b2cspec.constitution
description: B2C 프로젝트 헌법 조회 및 개정. `.b2cspec/constitution.md` 를 읽거나 제안된 개정사항을 검토하여 반영.
allowed-tools: Read, Edit, Write, AskUserQuestion, Grep
---

# /b2cspec.constitution — B2C 헌법 조회 · 개정

`.b2cspec/constitution.md` 의 프로젝트 불변 원칙을 조회하거나 개정한다. CLAUDE.md / `.docs/conventions/*` 와의 일치성도 함께 점검.

## 사용 예시

```
/b2cspec.constitution                          # 헌법 전체 조회
/b2cspec.constitution 제 7 조                   # 특정 조항 조회
/b2cspec.constitution amend "제 7 조에 XX 추가" # 개정 제안
/b2cspec.constitution check                    # 현재 코드가 헌법에 부합하는지 전체 점검
```

## 실행 단계

### 1단계: 모드 판별
사용자 입력 분석:
- **조회 모드**: 인자 없음 또는 조항 번호 (`제 N 조`)
- **개정 모드**: `amend`, `추가`, `수정`, `삭제` 등 키워드 포함
- **점검 모드**: `check`, `점검`, `감사` 키워드

### 2단계 (조회 모드): 헌법 표시
`.b2cspec/constitution.md` 를 Read 후:
- 전체 조회: 목차 + 전문 출력
- 조항별 조회: 해당 장/조 섹션만 추출 출력
- 관련 세부 문서 링크 함께 안내

### 3단계 (개정 모드): 개정 절차

#### 3.1 개정 제안 분석
사용자 제안을 파싱하여 다음을 확인:
- 개정 대상 장/조
- 변경 유형 (신규 조항 / 기존 조항 수정 / 삭제)
- 변경 이유

부족하면 `AskUserQuestion` 으로 보완.

#### 3.2 영향 범위 분석
개정 예정 조항과 관련된 다음 문서를 Grep:
- CLAUDE.md
- `.docs/conventions/project-convention.md`
- `.docs/conventions/api-convention.md`
- `.docs/conventions/test-convention.md`
- `.docs/conventions/string-resource-convention.md`
- `.docs/conventions/ui-convention.md`
- `.docs/test/mock-patterns.md`
- `.docs/test/coverage-guide.md`

각 문서의 관련 서술 부분을 리스트업.

#### 3.3 개정안 작성
`.b2cspec/constitution-amendments/{YYYYMMDD-HHMM}-{slug}.md` 에 개정안을 먼저 작성:

```markdown
# 헌법 개정안 {번호}

- 제안일: YYYY-MM-DD
- 제안자: {사용자}

## 대상
제 X 장 제 Y 조

## 변경 내용 (before → after)
### Before
{기존 텍스트}

### After
{변경 텍스트}

## 이유
...

## 영향 문서
- CLAUDE.md: {변경 필요한 섹션}
- .docs/conventions/xxx.md: {변경 필요한 섹션}

## 코드 영향
- {해당되는 경우 구체적 코드 변경 예상}
```

#### 3.4 사용자 승인
개정안을 출력하고 `AskUserQuestion` 으로 승인 요청:
- 승인 → constitution.md Edit 으로 반영 + 영향 문서 업데이트 태스크 제안
- 거부 → 개정안 파일은 `rejected/` 로 이동
- 보류 → 개정안 파일 유지

#### 3.5 반영
승인 시:
- `.b2cspec/constitution.md` Edit
- 본 조항 하단에 "개정 이력" 추가
- 영향 문서 목록을 `AskUserQuestion` 으로 제시: "지금 같이 업데이트할까요?" → Yes 면 순차 Edit

### 4단계 (점검 모드): 전체 감사

현재 코드베이스가 헌법에 부합하는지 점검. 각 조항을 자동/반자동으로 검증:

#### 제 4 조 (멀티모듈 의존성)
```bash
grep -l "core:data[^-]" feature/*/build.gradle.kts
```
feature 모듈이 `core:data` 를 직접 의존하는 경우 Violation.

#### 제 5 조 (MVI)
- `viewModel.uiState.value\s*=` Grep (금지된 직접 할당)
- `viewModel.container` Grep (Orbit 잔재 확인)

#### 제 6 조 (Navigation)
- 신규 `*Activity.kt` 파일 존재 여부 (feature 모듈 내)

#### 제 7 조 (데이터 레이어)
- `ResponseBase` import 여부 (금지)
- RepositoryImpl 가 `public` / `open` 인지 확인 (internal 이어야 함)
- Entity 에 `SuccessResponseMapper` 구현 여부

#### 제 10 조 (Kover / JaCoCo)
- `jacoco` 관련 Gradle 설정 여부
- `coverage-guide.md` 와 실제 설정 일치

#### 제 14 조 (문자열 리소스)
- `Text("[가-힣]")` 패턴 Grep (하드코딩된 한글)

#### 제 16 조 (비밀 관리)
- `Log.d.*jwt|token|password` 같은 패턴 검색

각 항목별로 위반 개수 + 대표 파일 경로 출력.

### 5단계: 결과 보고

#### 조회 모드
```
헌법 조회: {조항 / 전문}

{내용 출력}

관련 문서:
- CLAUDE.md
- .docs/conventions/{...}
```

#### 개정 모드
```
헌법 개정안 {접수 / 반려 / 반영 완료}

개정 대상: 제 X 조
파일: .b2cspec/constitution-amendments/{timestamp}-{slug}.md

{반영 시}
✓ constitution.md 업데이트됨
영향 문서 업데이트 필요: N개
```

#### 점검 모드
```
헌법 준수 감사 결과

✅ 준수: N/N 조항
⚠️  경고: N
❌ 위반: N

주요 위반:
- 제 7 조: {파일} 에서 ResponseBase 사용
- 제 14 조: {파일} 에서 하드코딩 문자열 N건

권장 조치:
1. ...
```

## 작성 규칙

### 필수
- 헌법 개정은 **반드시 영향 문서 동기화**까지 고려
- 개정 이력은 조항 하단에 추가 (삭제 금지)
- 점검 결과는 기록 파일로 저장 가능 (`AskUserQuestion` 으로 사용자 선택)

### 금지
- constitution.md 를 묻지 않고 수정
- 개정 제안 없이 본 문서 Write (전면 재작성)
- 위반 탐지 시 자의적 Pass 판정

## 후속

- 개정 반영 후: 영향 문서 업데이트 → 기존 `create-commit` 스킬로 커밋
- 점검 위반 발견: 해당 파일을 spec 으로 연결 (`/b2cspec.specify`) 또는 즉시 수정

## 관련

- 헌법 본문: [.b2cspec/constitution.md](../../../.b2cspec/constitution.md)
- 컨벤션 문서: `.docs/conventions/`
- CLAUDE.md: 루트

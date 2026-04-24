---
name: b2b-android-commit
description: Git 커밋 자동 생성. "커밋 해줘", "커밋 만들어줘", "commit", "변경사항 저장" 요청 시 사용
allowed-tools: Bash, Read
user-invocable: true
---

# Git 커밋 자동 생성 스킬

staged/unstaged 변경사항을 분석하여 프로젝트 컨벤션에 맞는 커밋을 생성한다.

## 실행 단계

### 0단계: Pre-commit 스킬 트리거 (선택적)
staged된 Kotlin/Java 파일이 있는 경우 `import-cleaner` 스킬 자동 실행:
- 미사용 import 감지 및 정리
- 정리된 파일 자동 re-stage
- **자동 생략**: 정리할 import가 없으면 스킵
- 수동 스킵: `--skip-import-clean`

### 1단계: 필수 문서 읽기
커밋 전 반드시 Read 도구를 사용하여 다음 문서를 읽고 규칙을 완전히 숙지:
- `.docs/conventions/commit-convention.md` — 커밋 메시지 형식, type/scope 규칙
- `CLAUDE.md` — 커밋 관련 프로젝트 규칙

### 2단계: 변경사항 분석
```bash
git status --porcelain
git diff --staged
```

### 3단계: 커밋 분리 판단

#### 기본 원칙
- **기능 단위 우선**: 파일이 아닌 기능/작업 단위로 커밋 분리
- **논리적 작업 그룹화**: 하나의 기능을 위해 여러 파일이 수정되었다면 함께 커밋
- 하나의 커밋 = 하나의 논리적 변경사항
- 같은 파일이라도 목적이 다르면 분리

#### 작업 목적별 분류
- 컴파일 에러 수정 (import, 타입 수정 등) → 하나의 커밋
- 새로운 테스트 추가 → 별도 커밋
- 리팩토링 → 별도 커밋
- 버그 수정 → 별도 커밋

#### 작업 순서에 따른 커밋 분리
1. 인터페이스/Contract 정의
2. 데이터 모델(Vo) 추가
3. Repository 구현 (API 호출, 데이터 처리)
4. ViewModel 구현 (상태 관리, 비즈니스 로직)
5. UI(Activity, Fragment, Compose) 구현
6. 테스트 코드 추가

### 4단계: 커밋 메시지 생성

#### 형식
`<type>(<scope>): <subject>`

#### Type
feat | fix | refactor | ui | chore | docs | test | style | remove

#### Scope
파일 경로 기반 자동 판단 (대부분 `b2b`)

#### Subject
한글, 50자 이내, 마침표 없음, 현재형 동사

#### 구체적인 커밋 메시지 작성법
**포괄적 표현 금지** — 아래 7가지 패턴을 절대 사용하지 않는다:

```
❌ fix(b2b): 데이터 모델 타입 수정
✅ fix(b2b): IncentiveRateType.PAYMENT_METHOD_DETAIL → PAYMENT_METHOD enum명 변경

❌ feat(b2b): ViewModel 실 데이터 연결
✅ remove(b2b): ViewModel Mock 데이터 생성 코드 제거

❌ ui(b2b): 화면 실 데이터 바인딩
✅ ui(b2b): 저장 버튼 isDataChanged 활성화 조건 추가

❌ feat(b2b): 실 데이터 연결
✅ feat(b2b): CustomerRepository.getCustomerList() API 호출 연결

❌ refactor(b2b): 모델 수정
✅ refactor(b2b): CustomerVo.status 타입 String → CustomerStatus enum 변환

❌ ui(b2b): 화면 업데이트
✅ ui(b2b): 고객 상세 > 메모 입력 필드 최대 200자 제한 추가

❌ fix(b2b): 버그 수정
✅ fix(b2b): 빈 이미지 리스트 IndexOutOfBoundsException 방어 처리
```

#### 변경 내용 구체화 미세 규칙
- **enum/상수명 변경 시**: 이전값 → 새값 명시 (예: `PAYMENT_METHOD_DETAIL → PAYMENT_METHOD`)
- **버튼/UI 변경 시**: 어떤 상태/이벤트가 변경됐는지 명시
- **Mock 데이터 제거 시**: "Mock 데이터 제거"로 충분 (줄 수 불필요)
- **import 정리**: 주요 변경사항이 아니면 생략
- **화면 경로**: `>` 기호로 표현 (예: `고객 상세 > 메모 입력 필드`)
- **파일 변경사항**: 단순 나열 대신 의도와 목적 설명

### 5단계: Git 변경사항 처리 및 커밋 실행

#### 처리 전략
- **Staged 파일 우선 처리**: 이미 `git add`된 파일들은 즉시 커밋 진행
#### 처리 순서
1. Staged 파일들로 먼저 커밋 실행
2. Unstaged 파일이 있으면 사용자에게 확인 요청 (무단 stage 절대 금지)
3. 사용자 동의 후 필요한 파일만 개별 `git add <파일경로>`로 stage
4. `git add .` 또는 `git commit -a` 사용 금지

#### 커밋 명령
```bash
git commit -m "type(scope): subject"
```

## 핵심 규칙

### ⛔ 금지
- 본문(body), 꼬리말(footer) 작성
- Co-Authored-By 추가
- `git add .` 일괄 추가 — 반드시 개별 파일 경로로 처리
- unstaged 파일 무단 stage
- 하나의 커밋에 여러 기능 포함
- 서로 다른 이슈의 수정사항을 같은 커밋에 포함

### ✅ 필수
- 제목 한 줄만 (`git commit -m "type(scope): subject"` 형식)
- 구체적 변경사항 명시
- 작업 단위별 분리 커밋
- 각 커밋은 독립적으로 의미 있고, revert해도 다른 기능에 영향 없어야 함

## 작은 단위 커밋 원칙

### 한 커밋 = 하나의 목적
각 커밋은 단 하나의 명확한 목적만 가져야 한다.

#### 작업 세분화 예시
- Import 문 추가 → 별도 커밋
- 타입/파라미터 오류 수정 → 별도 커밋
- 새로운 메서드 추가 → 별도 커밋
- 리팩토링 → 별도 커밋
- 버그 수정 → 별도 커밋
- UI 텍스트 변경 → 별도 커밋
- 로직 변경 → 별도 커밋

#### 실제 분리 예시 (ShopAlbumDetail 마이그레이션)
같은 기능이라도 다음과 같이 작은 단위로 분리:
1. `feat(b2b): ShopAlbumDetail onResume에서 데이터 갱신 추가`
2. `feat(b2b): ShopAlbumDetailUiState에 type 파라미터 추가`
3. `refactor(b2b): ShopAlbumDetailViewModel init 블록 제거`
4. `ui(b2b): ShopAlbumDetail 수정 화면 진입 시 하단 버튼 숨김 처리`
5. `ui(b2b): 페이지 인디케이터 간격 조정`
6. `fix(b2b): 빈 이미지 리스트 IndexOutOfBoundsException 방어 처리`

각 커밋은 독립적으로 의미가 있고, 다른 커밋 없이도 이해 가능해야 함

### 전체 처리 순서
1. 현재 작업의 모든 변경사항 분석
2. **변경사항을 목적별로 세분화**:
    - 컴파일 에러 수정 관련 (import, 타입 등)
    - 버그 수정 관련
    - 새 기능 추가 관련
    - 리팩토링 관련
    - 문서/주석 관련
3. **각 목적별로 최소 단위 커밋 생성**
4. **커밋 순서 결정**:
    - 의존성 있는 변경사항은 순서대로
    - 독립적인 변경사항은 논리적 순서로
5. 각 커밋마다 구체적이고 명확한 메시지 작성
6. 작업 완료 후 커밋 히스토리 요약 제공

## 추가 기능
- **추가 컨텍스트**: 사용자가 제공한 추가 정보를 커밋 메시지에 반영
- **파일명 기반 추론**: 변경된 파일명으로 기능 추론하여 더 정확한 커밋 메시지 생성

## 연계 스킬 (Pre-commit Chain)

| 순서 | 스킬 | 설명 | 트리거 조건 |
|-----|------|------|-----------|
| 0 | `import-cleaner` | 미사용 import 정리 | Kotlin/Java 파일 staged 시 |
| - | `code-formatter` | 코드 포맷팅 (예정) | 설정 활성화 시 |
| - | `todo-scanner` | TODO 주석 검사 (예정) | 설정 활성화 시 |

### 스킵 옵션
```bash
# import-cleaner 스킵
/commit --skip-import-clean

# 모든 pre-commit 스킵
/commit --skip-pre-commit
```

## 상세 규칙

상세 컨벤션: [commit-convention.md](../../../.docs/conventions/commit-convention.md) 참조

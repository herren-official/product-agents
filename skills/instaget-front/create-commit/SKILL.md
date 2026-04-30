---
name: instaget-front-create-commit
description: 인스타겟 프론트엔드 커밋 컨벤션에 따라 변경사항을 분석하고 파일별로 분리하여 커밋 생성
---

# 자동 커밋 생성 (인스타겟 웹)

현재 변경사항을 분석하여 인스타겟 프론트엔드 커밋 규칙에 따라 자동으로 커밋을 생성합니다.

## 사용법

```bash
/instaget-front-create-commit              # 기본 자동 커밋
/instaget-front-create-commit "추가 요구사항"  # 추가 컨텍스트와 함께 커밋
```

## 핵심 규칙

1. **커밋 메시지는 반드시 한글로만 작성** (영어 사용 절대 금지)
2. **파일별로 최대한 작은 단위로 커밋 분리**
3. **티켓 ID는 현재 브랜치명에서 IQLX-XXXX 패턴 추출**
4. **본문(body), 꼬리말(footer) 작성하지 않음** — 제목 한 줄만 사용

## 처리 단계

### 1. 변경사항 분석

아래 명령어를 **병렬로** 실행한다.

```bash
# 현재 브랜치 확인 및 티켓 ID 추출
git branch --show-current

# 변경된 파일 확인
git status

# staged + unstaged 변경 내용 확인
git diff
git diff --cached

# 최근 커밋 메시지 스타일 확인
git log --oneline -5
```

**주의사항:**
- 변경사항이 없으면 커밋하지 않는다.
- `.env`, `credentials`, API 키 등 민감 파일이 포함되어 있으면 경고한다.

### 2. 티켓 ID 추출

- 현재 브랜치명에서 `IQLX-XXXX` 패턴을 자동 추출한다.
- 예: `IQLX-7201-feat-gtm-click-tracking` → `IQLX-7201`
- 티켓 ID를 찾을 수 없으면 사용자에게 확인 요청한다.
- **다른 티켓 번호 사용 금지** — 반드시 현재 브랜치의 티켓 번호만 사용한다.

### 3. 커밋 분리 전략 결정

**분리 원칙 (최대한 작은 단위로 분리):**

1. **파일별 분리**: 서로 다른 파일의 수정은 별도 커밋으로 분리
2. **기능별 분리**: 하나의 파일이라도 다른 기능 수정은 별도 커밋
3. **타입별 분리**: 같은 파일이라도 refactor와 style은 별도 커밋
4. **논리적 단위 분리**:
   - UI 수정과 문서 수정은 별도 커밋
   - 여러 컴포넌트 수정은 각각 별도 커밋
   - 기능 추가와 스타일 수정은 별도 커밋

단, 의존성 있는 파일(새 모듈 + import하는 파일)은 함께 커밋한다.

**커밋 계획 승인은 반드시 `AskUserQuestion` Form으로 요청한다**:

```jsonc
// AskUserQuestion 호출 템플릿
{
  "questions": [{
    "question": "위 커밋 계획을 승인하시겠습니까?",
    "header": "커밋 승인",
    "options": [
      { "label": "승인", "description": "위 계획대로 N개 커밋을 생성합니다" },
      { "label": "커밋 메시지 수정", "description": "커밋 메시지를 변경합니다" },
      { "label": "커밋 분리 변경", "description": "커밋 분리 전략을 변경합니다" }
    ],
    "multiSelect": false
  }]
}
```

### 4. 커밋 메시지 작성

#### 형식

```
type(IQLX-XXXX): 한글 설명
```

#### 커밋 타입 (아래 목록에서만 선택)

- `feat`: 새로운 기능 추가
- `fix`: 버그 수정
- `style`: 스타일 변경 (코드 포맷팅, 세미콜론 누락 등 코드 변경 없는 경우)
- `refactor`: 코드 리팩토링
- `test`: 테스트 코드 추가 또는 수정
- `chore`: 빌드 업무, 패키지 매니저 설정, 개발 환경 변경 등
- `docs`: 문서 수정

> **주의**: `perf`, `ci`, `build` 등 일반 Conventional Commits 타입이라도 위 목록에 없으면 사용하지 않는다.

#### Subject 규칙

- **반드시 한글로만 작성** (영어 사용 금지)
- 소문자로 시작
- 마침표로 끝나지 않음
- 명령문 사용
- 50자 이내

#### 예시

```bash
# 좋은 예
feat(IQLX-7201): GTM 클릭 이벤트 트래킹 추가
fix(IQLX-7201): 배너 이미지 인덱스 수정
refactor(IQLX-7201): trackGtm 헬퍼 함수로 추출
style(IQLX-7201): 코드 포맷팅 적용
test(IQLX-7201): MainBannerSwiper 컴포넌트 유닛 테스트 작성

# 나쁜 예
feat(IQLX-7201): add GTM tracking    # ❌ 영어 사용
feat(IQLX-7201): GTM 추가.           # ❌ 마침표
refactor(IQLX-6314): 모달 UI 개선 및 문서 수정  # ❌ 여러 작업 합침
```

### 5. 커밋 실행

```bash
# 파일별로 git add 실행
git add {file1}

# 커밋 (본문 없이 제목만)
git commit -m "$(cat <<'EOF'
type(IQLX-XXXX): 한글 설명

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

**규칙:**
- `git add .` 또는 `git add -A` 대신 파일을 명시적으로 추가한다.
- 민감 파일은 절대 스테이징하지 않는다.

### 6. 결과 보고

```bash
git log --oneline -n {커밋 수}
git status
```

- 생성된 커밋 목록 표시
- 최종 상태 확인

## 주의사항

- **커밋 메시지는 반드시 한글** — 영어 사용 절대 금지
- **본문(body)은 절대 작성하지 않음** — 제목 한 줄만 사용
- 항상 사용자에게 커밋 계획 확인 요청
- 빌드가 깨지지 않도록 의존성 있는 파일은 함께 커밋
- PR 리뷰어 관점에서 논리적 그룹화
- **패키지 매니저는 yarn 사용** (npm 아님)

---
name: b2b-web-review-pr
description: "오픈된 PR 코드 리뷰 자동 분석 및 제출 (P1/P2/P3 우선순위 기반)"
argument-hint: "[PR번호 | 'all' | 'pending' | '--dry-run' | '--cached']"
allowed-tools: ["bash", "read", "grep", "glob"]
---

# PR 코드 리뷰

인자: $ARGUMENTS

## 개요

오픈된 GitHub PR의 코드를 로컬에서 분석하고, 프로젝트 컨벤션 기반의 P1/P2/P3 우선순위 리뷰를 생성하여 GitHub에 제출합니다.
브랜치 전환 없이 `git fetch` + `git show`와 `gh pr diff`를 사용하여 변경사항을 분석합니다.

## 옵션

| 옵션 | 설명 |
|------|------|
| `--dry-run` | 리뷰 생성만 하고 제출하지 않음 (미리보기 모드) |
| `--cached` | 이전 분석 결과가 있으면 재사용 |
| `--no-coderabbit` | CodeRabbit 리뷰 확인 건너뛰기 |
| `--template=<name>` | 커스텀 리뷰 템플릿 사용 |
| `--focus=<area>` | 특정 영역만 집중 분석 (performance, security, architecture) |

## 처리 단계

### 0단계: 환경 검증 및 초기화

```bash
# GitHub CLI 인증 확인
gh auth status

# 저장소 확인
git remote get-url origin

# 네트워크 연결 확인 (타임아웃 5초)
timeout 5 gh api rate_limit --jq '.rate.remaining' || echo "NETWORK_ERROR"

# 이전 리뷰 캐시 확인 (있으면 로드)
CACHE_DIR=".claude/review-cache"
```

**에러 처리**:
- `gh auth status` 실패 → "GitHub CLI 인증이 필요합니다. `gh auth login`을 실행해주세요." 출력 후 종료
- 네트워크 오류 → "네트워크 연결을 확인해주세요." 출력 후 종료
- Rate limit 잔여 < 50 → "GitHub API rate limit이 부족합니다. (잔여: N) 잠시 후 다시 시도해주세요." 경고

### 1단계: PR 목록 조회 및 선택

인자가 **PR 번호**인 경우 해당 PR로 바로 2단계로 진행합니다.
인자가 **여러 PR 번호** (예: `3845 3846`)인 경우 배치 모드로 순차 리뷰합니다.

인자가 없거나 `pending` 또는 `all`인 경우:

```bash
gh pr list --state open --json number,title,author,reviewDecision,reviews,headRefName,baseRefName,changedFiles,additions,deletions,url,labels,createdAt,updatedAt
```

**필터링 규칙**:
- **기본/pending**: 본인이 작성하지 않은 PR 중, `reviews` 배열에 본인(`kiwi-herren`)의 `APPROVED` 또는 `CHANGES_REQUESTED` 상태 리뷰가 없는 PR만 표시
- **all**: 본인이 작성하지 않은 모든 오픈 PR 표시

테이블 형태로 표시:

```
# 리뷰 대기 PR 목록

| # | PR   | 제목                              | 작성자    | 변경            | 상태             | 생성일     |
|---|------|-----------------------------------|----------|-----------------|------------------|-----------|
| 1 | 3846 | GBIZ-24349: 영업시간저장 캘린더 적용 | marty404 | +82/-15 (6파일) | REVIEW_REQUIRED  | 2일 전    |
| 2 | 3845 | GBIZ-24347: 휴무일 저장 캘린더 적용  | marty404 | +140/-22 (8파일) | REVIEW_REQUIRED | 3일 전    |
```

사용자에게 선택 요청: "리뷰할 PR 번호를 선택해주세요 (쉼표로 여러 개 선택 가능, 'q'로 취소)"

**예외 처리**:
- 리뷰 대기 PR이 없는 경우: "리뷰 대기 중인 PR이 없습니다." 출력 후 종료
- 본인 PR 선택 시: "이 PR은 본인이 작성한 PR입니다. self-review로 진행하시겠습니까?" 경고
- 이미 approve한 PR 선택 시: "이미 이 PR을 approve 하셨습니다. 추가 리뷰를 남기시겠습니까?" 경고
- PR 번호가 존재하지 않는 경우: "PR #N을 찾을 수 없습니다." 에러

### 2단계: PR 메타데이터 및 컨텍스트 수집

선택된 각 PR에 대해 수집:

```bash
# PR 상세 정보
gh pr view <number> --json title,body,author,headRefName,baseRefName,headRefOid,files,additions,deletions,commits,url,labels,milestone,linkedIssues

# 전체 diff
gh pr diff <number>

# 커밋 히스토리 (변경 패턴 분석용)
gh pr view <number> --json commits --jq '.commits[].messageHeadline'

# 기존 리뷰 확인 (CodeRabbit 등)
gh api repos/herren-official/gongbiz-crm-b2b-web/pulls/<number>/reviews

# 기존 라인별 코멘트 확인
gh api repos/herren-official/gongbiz-crm-b2b-web/pulls/<number>/comments

# 연관 이슈 확인 (PR body에서 링크된 이슈)
# body에서 "fixes #123", "closes #123", "GBIZ-12345" 패턴 추출

# 이전 내 리뷰 히스토리 확인 (같은 PR에 이전 리뷰가 있는지)
gh api repos/herren-official/gongbiz-crm-b2b-web/pulls/<number>/reviews \
  --jq '.[] | select(.user.login == "kiwi-herren")'
```

**이전 리뷰 히스토리가 있는 경우**:
```
ℹ️ 이전 리뷰 발견 (2024-01-15)
- 상태: CHANGES_REQUESTED
- 주요 지적: P1 2건, P2 3건
- 해결된 것으로 보이는 항목: 2건
→ 이전 리뷰 대비 변경사항을 중심으로 분석합니다.
```

**변경 패턴 분석** (커밋 메시지 기반):
- `fix:`, `bugfix:`, `hotfix:` → 버그 수정 모드 (기존 동작 보존 검증 강화)
- `refactor:` → 리팩토링 모드 (동작 변경 없음 검증)
- `feat:` → 신규 기능 모드 (기능 완성도 검증)
- `perf:` → 성능 개선 모드 (성능 측정 가능성 검증)
- `chore:`, `style:` → 경량 리뷰 모드

### 3단계: 파일 내용 읽기 (브랜치 전환 없이)

```bash
# PR 브랜치 fetch (working tree 변경 없음)
git fetch origin <headRefName> --depth=50

# 변경된 각 파일의 전체 내용 읽기 (PR 버전)
git show origin/<headRefName>:<filepath>

# 필요시 base 브랜치의 원본 파일 읽기 (비교용)
git show origin/<baseRefName>:<filepath>
```

**건너뛸 파일**:
- `build.json` (자동 생성)
- `*.lock`, `yarn.lock`, `package-lock.json`
- `*.min.js`, `*.min.css`
- 바이너리 파일 (이미지, 폰트 등)
- 자동 생성된 파일 (swagger codegen, graphql codegen 등)
- `.next/`, `node_modules/`, `dist/`, `build/` 하위 파일

**파일 유형별 분석 전략**:

| 파일 패턴 | 분석 전략 | 중점 검토 항목 |
|----------|----------|---------------|
| `src/hooks/*.ts` | Hook 전용 분석 | 의존성 배열, cleanup, 재사용성 |
| `src/components/**/*.tsx` | 컴포넌트 분석 | Props 설계, 렌더링 최적화, 접근성 |
| `src/pages/**/*.tsx` | 페이지 분석 | 데이터 페칭, SEO, 라우팅 |
| `src/utils/*.ts` | 유틸리티 분석 | 순수 함수, 테스트 용이성, 타입 안전성 |
| `src/types/*.ts` | 타입 분석 | 타입 정확성, 재사용성, 네이밍 |
| `src/styles/*.ts` | 스타일 분석 | 테마 활용, 일관성, 반응형 |
| `src/atoms/*.ts` | 상태 분석 | Atom 설계, selector 효율성 |
| `src/queries/*.ts` | 쿼리 분석 | Query Factory 패턴, 캐시 전략 |
| `*.test.ts`, `*.spec.ts` | 테스트 분석 | 커버리지, 엣지 케이스, mocking |
| `*.stories.tsx` | 스토리북 분석 | 스토리 완성도, 문서화 |

**대용량 파일 처리**:
- 500줄 이상 변경된 파일: diff의 변경 hunk + 전후 30줄 컨텍스트만 분석
- 전체 PR이 20개 이상 파일 또는 1000줄 이상 변경: 
  ```
  ⚠️ PR 크기가 큽니다 (+1,234/-567, 25개 파일)
  도메인/컴포넌트별로 나누어 리뷰하겠습니다.
  
  분석 순서:
  1. components/Calendar/* (8개 파일)
  2. hooks/* (5개 파일)
  3. pages/* (4개 파일)
  4. 기타 (8개 파일)
  ```

### 4단계: 컨벤션 문서 로드

다음 프로젝트 컨벤션 문서를 읽어 분석 기준으로 사용:

```bash
# 필수 컨벤션 문서
.docs/conventions/CODE_REVIEW_CONVENTIONS.md   # 리뷰 체크리스트, P1/P2/P3 시스템
.docs/conventions/CODING_CONVENTIONS.md        # import 순서, 네이밍, 비동기 처리
.docs/conventions/REACT_CONVENTIONS.md         # 컴포넌트 구조, Hook 규칙
.docs/conventions/UI_STYLING_RULES.md          # styled-components, 테마 사용
.docs/conventions/STATE_MANAGEMENT.md          # Recoil, React Query 패턴

# 선택적 컨벤션 (파일 존재 시)
.docs/conventions/NEXTJS_CONVENTIONS.md        # Next.js 13+ 규칙
.docs/conventions/TESTING_CONVENTIONS.md       # 테스트 작성 규칙
.docs/conventions/ACCESSIBILITY_GUIDE.md       # 접근성 가이드
```

**컨벤션 파일 누락 시**:
- 필수 파일 누락: "⚠️ {파일명} 컨벤션 문서가 없습니다. 기본 규칙으로 분석합니다." 경고
- 분석은 계속 진행 (기본 best practice 적용)

### 5단계: 코드 분석

CODE_REVIEW_CONVENTIONS.md의 체크리스트를 기반으로 분석합니다.

#### 5.1 기능적 측면
- PR body의 작업 내용 기준 요구사항 충족 여부
- 연관 이슈/티켓 요구사항 반영 여부
- 엣지 케이스 처리 (null/undefined, 빈 배열, 경계값)
- 에러 처리 적절성 (try-catch, error boundary, fallback UI)
- 이전 리뷰 지적사항 해결 여부 (히스토리가 있는 경우)

#### 5.2 코드 품질
- 가독성, 이해 용이성
- 코드 중복 여부
- 네이밍 명확성 (CODING_CONVENTIONS.md 기준)
  - Props: `ComponentNameProps`
  - Params: `FunctionNameParams`
  - Hook Params: `HookNameParams`
- import 순서: React → 외부 라이브러리 → 내부 컴포넌트/Hook → 타입 → 스타일 → 상수/유틸
- `import type` 사용 여부
- 매직 넘버/스트링 상수화

#### 5.3 성능 및 보안
- 불필요한 리렌더링 (useCallback/useMemo 필요성)
- useEffect cleanup 누락 (메모리 누수)
- 보안 취약점 (XSS, dangerouslySetInnerHTML 등)
- React Query 캐시 무효화 패턴 적절성
- 번들 크기 영향 (큰 라이브러리 import)
- 이미지 최적화 (next/image 사용 여부)

#### 5.4 Next.js 13+ 관련 (해당 시)
- 서버 컴포넌트 vs 클라이언트 컴포넌트 구분 적절성
- `'use client'` 디렉티브 필요성/누락
- 서버 컴포넌트에서 클라이언트 전용 API 사용 (useState, useEffect 등)
- 메타데이터 API 활용 (SEO)
- 동적 라우팅 패턴

#### 5.5 TypeScript 엄격성
- any 타입 사용 (P2 이슈)
- as 타입 단언 남용
- 타입 가드 적절성
- Generic 활용 적절성
- 유니온/인터섹션 타입 설계

#### 5.6 테스트
- 새 코드에 대한 테스트 존재 여부
- 엣지 케이스 테스트
- 테스트 커버리지 예상
- Mocking 적절성

#### 5.7 아키텍처
- 컴포넌트 책임 분리 (SRP)
- Hook 설계 적절성
- 재사용성 고려
- 의존성 방향 (상위 → 하위)

#### CodeRabbit과의 차별화 포인트
- CodeRabbit이 이미 지적한 이슈는 중복 지적하지 않음 (동의 시 "[CodeRabbit 동의]" 표기)
- **비즈니스 로직 정확성**에 집중
- **아키텍처 관점** (컴포넌트 책임 분리, Hook 설계)
- **프로젝트 고유 패턴** 위반 (Query Factory, Recoil atom 구조, styled-components 규칙)
- **Next.js 13+ 특화** 검사
- 사소한 스타일 이슈는 CodeRabbit에 위임

### 6단계: 리뷰 결과 생성

다음 형식으로 사용자에게 리뷰 결과를 표시합니다:

```markdown
# PR #<number> 코드 리뷰: <title>

## 요약
- 작성자: <author>
- 변경: +<additions>/-<deletions> (<changedFiles> files)
- 브랜치: <headRefName> → <baseRefName>
- 변경 패턴: <신규 기능 | 버그 수정 | 리팩토링 | 기타>
- 연관 이슈: <GBIZ-12345 | 없음>

## 이전 리뷰 히스토리
<!-- 이전 리뷰가 있는 경우 -->
- 이전 리뷰: CHANGES_REQUESTED (2024-01-15)
- 지적 사항 중 해결된 것: 3/5건
- 미해결 이슈: P1 1건 (아래에서 재지적)

## CodeRabbit 리뷰 요약
<!-- CodeRabbit이 이미 지적한 내용이 있으면 간략히 요약 -->
- 총 N건의 코멘트
- 주요 지적: ...

---

## 리뷰 결과

### 🔴 P1: 꼭 반영해 주세요 (Request Changes)
<!-- P1 이슈가 있는 경우만 표시 -->

**[파일명:라인번호]** 이슈 제목
> 구체적인 설명

**현재 코드:**
```tsx
// 문제가 있는 코드
```

**수정 제안:**
```tsx
// 개선된 코드
```

---

### 🟡 P2: 반영을 적극 고려해 주세요 (Comment)
<!-- P2 이슈가 있는 경우만 표시 -->
**[파일명:라인번호]** 이슈 제목
> 구체적인 설명과 수정 제안

### 🟢 P3: 참고 의견 (Chore)
<!-- P3 이슈가 있는 경우만 표시 -->
**[파일명:라인번호]** 이슈 제목
> 설명

### 👍 잘한 점
<!-- 좋은 코드가 있으면 칭찬과 격려 (CODE_REVIEW_CONVENTIONS.md 4.1 리뷰어 원칙) -->
1. **[파일명]** 설명
2. ...

---

## 체크리스트

### 기능
- [x/ ] 요구사항 충족
- [x/ ] 엣지 케이스 처리
- [x/ ] 에러 처리

### 코드 품질
- [x/ ] 코드 가독성
- [x/ ] 중복 코드 없음
- [x/ ] 네이밍 명확성
- [x/ ] import 순서

### 성능/보안
- [x/ ] 불필요한 리렌더링 없음
- [x/ ] 메모리 누수 없음
- [x/ ] 보안 취약점 없음

### Next.js (해당 시)
- [x/ ] 서버/클라이언트 컴포넌트 구분
- [x/ ] 'use client' 적절한 사용

### 테스트
- [x/ ] 테스트 코드 존재
- [x/ ] 엣지 케이스 테스트

---

## 추천 액션: APPROVE / COMMENT / REQUEST_CHANGES
이유: <추천 근거 설명>
```

**추천 기준**:
- P1 이슈가 1건이라도 있으면 → **REQUEST_CHANGES**
- P1 없고 P2만 있으면 → **COMMENT** (P2가 3건 이상이면 REQUEST_CHANGES 고려)
- P1, P2 모두 없으면 → **APPROVE**

### 7단계: 사용자 확인

리뷰 결과를 표시한 후 사용자에게 확인 요청:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
리뷰 내용을 확인해주세요.

1. 이대로 제출 (추천: <ACTION>)
2. 수정 후 제출 (리뷰 내용을 직접 수정)
3. 액션 변경 (예: APPROVE → COMMENT)
4. 라인별 코멘트 추가/제거
5. 특정 이슈 제거 (예: P2-1 제거)
6. 칭찬 추가
7. 미리보기 (GitHub에 표시될 형태)
8. 취소

선택: 
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**--dry-run 옵션인 경우**:
```
🔍 Dry Run 모드: 리뷰가 생성되었지만 제출되지 않습니다.

위 리뷰 내용을 검토하신 후, 실제 제출하려면:
/review-pr <number>
```

**반드시 사용자 확인 후에만 제출합니다. 자동 제출 금지.**

### 8단계: 리뷰 제출

#### 제출 전 최종 확인

```bash
# Rate limit 재확인
gh api rate_limit --jq '.rate.remaining'

# PR 상태 재확인 (제출 사이에 업데이트 되었는지)
gh pr view <number> --json headRefOid --jq '.headRefOid'
```

**커밋이 변경된 경우**:
```
⚠️ 분석 이후 새로운 커밋이 푸시되었습니다.
- 분석 시점: abc1234
- 현재: def5678

1. 새 커밋 포함하여 재분석
2. 기존 분석 기준으로 제출 (outdated 리뷰 가능성)
3. 취소
```

#### 라인별 코멘트가 없는 경우

`gh pr review`를 사용하여 제출:

```bash
# APPROVE
gh pr review <number> --approve --body "<리뷰 본문>"

# COMMENT
gh pr review <number> --comment --body "<리뷰 본문>"

# REQUEST_CHANGES
gh pr review <number> --request-changes --body "<리뷰 본문>"
```

#### 라인별 코멘트가 있는 경우

`gh api`를 사용하여 리뷰와 inline comments를 한 번에 제출:

```bash
gh api repos/herren-official/gongbiz-crm-b2b-web/pulls/<number>/reviews \
  --method POST \
  --input - <<'EOF'
{
  "commit_id": "<headRefOid>",
  "body": "<리뷰 본문>",
  "event": "APPROVE|COMMENT|REQUEST_CHANGES",
  "comments": [
    {
      "path": "src/components/Example/index.tsx",
      "line": 42,
      "side": "RIGHT",
      "body": "🟡 **P2**: useMemo로 감싸면 성능이 개선될 것 같습니다.\n\n```tsx\nconst memoizedValue = useMemo(() => expensiveCalculation(a, b), [a, b]);\n```"
    }
  ]
}
EOF
```

**라인 번호 결정 방법**: `gh pr diff`의 unified diff에서 `+` 라인의 위치를 기반으로 `line` 값을 결정합니다. `side`는 항상 `RIGHT` (변경된 코드 쪽)를 사용합니다.

**제출 실패 시 에러 처리**:

```bash
# 401 Unauthorized
"GitHub 인증이 만료되었습니다. `gh auth login`으로 재인증해주세요."

# 403 Forbidden
"이 저장소에 리뷰 권한이 없습니다."

# 422 Unprocessable Entity
"리뷰 제출에 실패했습니다. PR이 이미 머지되었거나 닫혔을 수 있습니다."

# 네트워크 오류
"네트워크 오류로 제출에 실패했습니다.
아래 명령어로 수동 제출할 수 있습니다:

gh pr review <number> --comment --body '...'

또는 리뷰 본문이 클립보드에 복사되었습니다."
```

### 9단계: 캐시 저장 및 결과 보고

```bash
# 리뷰 결과 캐시 저장 (재분석 시 참조용)
mkdir -p .claude/review-cache
cat > .claude/review-cache/pr-<number>.json << 'EOF'
{
  "pr_number": <number>,
  "reviewed_at": "<ISO timestamp>",
  "commit_id": "<headRefOid>",
  "action": "APPROVE|COMMENT|REQUEST_CHANGES",
  "issues": {
    "p1": [...],
    "p2": [...],
    "p3": [...]
  },
  "submitted": true
}
EOF
```

**결과 보고**:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ PR #<number> 리뷰가 제출되었습니다!

📋 요약
- 액션: APPROVE
- P1: 0건 | P2: 2건 | P3: 1건
- 라인별 코멘트: 3건
- 칭찬: 2건

🔗 URL: <pr_url>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

배치 모드인 경우 진행 상황 테이블 표시 후 다음 PR로 진행:

```
## 리뷰 진행 상황

| PR    | 제목                   | 결과             | P1/P2/P3 | 상태        |
|-------|------------------------|-----------------|----------|-------------|
| #3846 | GBIZ-24349: 영업시간... | APPROVE         | 0/1/2    | ✅ 제출 완료 |
| #3845 | GBIZ-24347: 휴무일...  | REQUEST_CHANGES | 1/2/0    | ✅ 제출 완료 |
| #3844 | GBIZ-24350: 알림...    | (분석 중...)     | -        | ⏳ 진행 중  |

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
다음 PR (#3844)을 분석합니다. (Enter: 계속 / q: 중단)
```

**중단 처리**:
- 사용자가 'q' 입력 시: "리뷰가 중단되었습니다. 완료된 리뷰: N건" 출력 후 종료
- Ctrl+C 시: 현재 PR 리뷰 저장 여부 확인 후 종료

## GitHub 리뷰 본문 형식

GitHub에 실제 제출되는 리뷰 본문은 다음 형식을 따릅니다:

```markdown
## 코드 리뷰

### 📊 요약
| 항목 | 내용 |
|------|------|
| 변경사항 | +<additions>/-<deletions> (<changedFiles>개 파일) |
| 분석 패턴 | 신규 기능 개발 |
| 연관 이슈 | GBIZ-12345 |

---

### 🔴 P1: 꼭 반영해 주세요
> (없음 / 구체적 이슈 목록)

### 🟡 P2: 반영을 적극 고려해 주세요
1. **`파일명:라인`** - 구체적 설명

### 🟢 P3: 참고 의견
1. **`파일명:라인`** - 구체적 설명

### 👍 잘한 점
- 구체적인 칭찬 1
- 구체적인 칭찬 2

---

### ✅ 체크리스트
- [x] 요구사항 충족
- [x] 엣지 케이스 처리
- [x] 에러 처리
- [x] 코드 가독성
- [x] 성능/보안
- [ ] 테스트 코드 (추가 권장)

---
<sub>🤖 이 리뷰는 Claude Code Review를 통해 생성되었습니다.</sub>
```

## 커스텀 템플릿

`--template=<name>` 옵션으로 커스텀 템플릿을 사용할 수 있습니다.

템플릿 위치: `.claude/review-templates/<name>.md`

```markdown
<!-- .claude/review-templates/minimal.md -->
## 리뷰

{{#if p1_issues}}
### 🔴 P1
{{#each p1_issues}}
- {{this}}
{{/each}}
{{/if}}

{{#if p2_issues}}
### 🟡 P2
{{#each p2_issues}}
- {{this}}
{{/each}}
{{/if}}

{{#if good_points}}
### 👍
{{#each good_points}}
- {{this}}
{{/each}}
{{/if}}
```

## 사용 예시

```bash
# 리뷰 대기 PR 목록에서 선택하여 리뷰 (기본)
/review-pr

# 특정 PR 리뷰
/review-pr 3846

# 미리보기 모드 (제출하지 않음)
/review-pr 3846 --dry-run

# 이전 캐시 사용 (빠른 재리뷰)
/review-pr 3846 --cached

# 성능 집중 분석
/review-pr 3846 --focus=performance

# 보안 집중 분석
/review-pr 3846 --focus=security

# 리뷰 대기 PR 목록 (pending과 동일)
/review-pr pending

# 모든 오픈 PR 보기 (이미 리뷰한 것 포함)
/review-pr all

# 여러 PR 배치 리뷰
/review-pr 3845 3846 3847

# 커스텀 템플릿 사용
/review-pr 3846 --template=minimal

# CodeRabbit 확인 건너뛰기 (빠른 리뷰)
/review-pr 3846 --no-coderabbit
```

## 주의사항

### 필수 준수

1. **브랜치 전환 금지**: 현재 작업 중인 브랜치를 절대 변경하지 않습니다. `git fetch`와 `git show`만 사용합니다.

2. **자동 제출 금지**: 반드시 사용자 확인을 받은 후에만 리뷰를 제출합니다.

3. **리뷰어 원칙 준수** (CODE_REVIEW_CONVENTIONS.md 4.1):
   - 좋은 코드의 방향 제시 (수정 강제 X)
   - 좋은 코드 발견 시 **칭찬과 격려**
   - 건설적이고 구체적인 피드백 제공
   - 인신공격 금지, 코드에 집중

### 에러 처리

4. **네트워크 오류 복구**: 제출 실패 시 리뷰 본문을 출력하고, 수동 제출을 위한 `gh` 명령어를 제공합니다.

5. **Rate Limit 관리**: API 호출 전 잔여량 확인, 부족 시 경고 후 대기 또는 종료.

6. **타임아웃**: 각 API 호출은 30초 타임아웃, 전체 PR 분석은 5분 타임아웃.

### 분석 품질

7. **CodeRabbit 중복 방지**: CodeRabbit이 이미 리뷰한 내용은 중복 지적하지 않습니다. 동의하는 경우만 "[CodeRabbit 동의]"로 표기합니다.

8. **대규모 PR**: 변경 파일 20개 이상 또는 변경 1000줄 이상이면 도메인/컴포넌트별로 나누어 분석합니다.

9. **변경 패턴 인식**: 커밋 메시지를 분석하여 리팩토링/버그수정/신규기능에 맞는 리뷰 관점을 적용합니다.

10. **이전 리뷰 참조**: 같은 PR에 이전 리뷰가 있으면 해결 여부를 확인하고, 미해결 이슈는 재지적합니다.

## 트러블슈팅

### "gh: command not found"
```bash
# GitHub CLI 설치
brew install gh  # macOS
# 또는
sudo apt install gh  # Ubuntu
```

### "authentication required"
```bash
gh auth login
# 브라우저에서 인증 진행
```

### "rate limit exceeded"
```bash
# 현재 rate limit 확인
gh api rate_limit

# 리셋 시간까지 대기하거나, 인증된 토큰 사용
```

### "permission denied"
- 저장소에 대한 쓰기 권한이 있는지 확인
- PR이 다른 저장소(fork)에서 온 경우 권한 제한 있을 수 있음

### 리뷰가 outdated로 표시됨
- 분석 이후 새 커밋이 푸시된 경우 발생
- `--cached` 없이 재분석 권장
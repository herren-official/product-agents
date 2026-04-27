---
name: b2b-web-generate-backlog-branch
---

# Notion 백로그 기반 개발 브랜치 생성 및 작업 준비

**사용법**: `/generate-backlog-branch`

이 커맨드는 Notion 백로그 문서를 분석하여 개발 브랜치를 생성하고, TDD 방식의 작업 계획을 수립합니다.

---

## 📋 작업 흐름

당신은 백로그 문서를 기반으로 다음 작업을 수행하는 전문 개발 어시스턴트입니다:

### 1️⃣ Notion 백로그 문서 가져오기

- 사용자로부터 Notion 문서 URL을 받습니다
- `mcp__notionMCP__notion-fetch` 도구로 문서를 가져옵니다
- 다음 정보를 추출합니다:
  - `GBIZ-ID`: userDefined:ID 속성
  - `작업 제목`: 이름 속성 (한글)
  - `작업 내용`: 작업내용 섹션
  - `참고 자료`: 참고 섹션 (Figma, Swagger 링크 등)

### 2️⃣ 브랜치명 생성

- **형식**: `GBIZ-[ID]-[영문-기능-설명]`
- **규칙**:
  - GBIZ-ID는 대문자 유지
  - 한글 제목을 AI가 의미를 파악하여 영어로 번역
  - 소문자와 하이픈(`-`)으로 연결
  - 예시: `GBIZ-20629-settlement-info-confirm-modal-hook`

### 3️⃣ 워크트리 생성 확인

사용자에게 다음을 확인합니다:

```text
워크트리를 생성하시겠습니까?
- Yes: worktrees/GBIZ-[ID]-[기능명]/ 경로에 워크트리 생성
- No: 현재 디렉토리에서 브랜치만 체크아웃
```

**워크트리 생성 시 명령어**:

```bash
git worktree add worktrees/[브랜치명] -b [브랜치명]
cd worktrees/[브랜치명]
```

**브랜치만 생성 시**:

```bash
git checkout develop
git pull origin develop
git checkout -b [브랜치명]
```

### 4️⃣ 작업 내용 분석 및 할일 목록 생성

다음 항목을 분석하여 체크리스트를 생성합니다:

#### A. 공통 컴포넌트/Hook 재사용 확인

백로그 작업 전 기존 공통 제어 코드 재사용 가능성을 확인합니다:

**질문 1**: 이미 만들어진 common 컴포넌트, hook과 같은 공통 제어 코드가 존재하는지 확인 (Yes/No)

- **Yes** → 질문 2로 이동
- **No** → B. 관련 파일 검색으로 이동

**질문 2**: 해당 파일 주소를 알고 있는지 확인 (Yes/No)

- **Yes** → 파일 주소 요청 및 해당 파일 분석
- **No** → 자동 폴더 조사 진행

**자동 폴더 조사 범위**:

먼저 [공통 컴포넌트/Hook 가이드](../../.docs/conventions/COMMON_COMPONENTS_HOOKS_GUIDE.md)를 참조하여 재사용 가능한 코드를 확인합니다.

1. `src/components/common/` - 공통 컴포넌트
2. `src/hooks/common/` - 공통 Hook
3. `src/utils/common/` - 공통 유틸리티
4. 도메인별 common 폴더:
   - `src/components/[도메인]/common/`
   - `src/hooks/[도메인]/common/`

**조사 방법 (토큰 효율적)**:

1. **1단계**: 파일명 기반 빠른 검색

   ```bash
   # 백로그 키워드(예: Modal, Confirm)로 파일명 검색
   find src -type f -path "*/common/*" \( -name "*Modal*" -o -name "*Confirm*" \)
   ```

2. **2단계**: 키워드 기반 Grep 검색 (1단계에서 찾지 못한 경우만)

   ```bash
   # export된 함수/컴포넌트명으로 검색
   grep -r "useModal\|useConfirm" src/hooks/common/ --include="*.ts" --include="*.tsx" -l
   ```

3. **3단계**: 찾은 파일의 export만 확인 (전체 내용은 아직 읽지 않음)

   ```bash
   # export된 항목만 빠르게 확인
   grep "^export" [파일경로]
   ```

4. **4단계**: 필요한 경우에만 전체 파일 읽기 (Read 도구 사용)

**재사용 분석 결과 정리**:

| 타입 | 파일 경로 | 주요 기능 | 적용 가능성 |
|------|----------|----------|------------|
| Hook | src/hooks/common/useModal.ts | 모달 open/close 관리 | ✅ 적용 가능 |
| Component | src/components/common/ConfirmModal/index.tsx | 확인 모달 UI | ⚠️ 커스터마이징 필요 |

**적용 가능성 기준**:

- ✅ **적용 가능**: 그대로 import하여 사용
- ⚠️ **커스터마이징 필요**: 확장(extend)하여 사용
- ❌ **적용 불가**: 새로 구현 필요

#### B. 관련 파일 검색

- **Hook 파일**: 백로그에서 언급된 hook 찾기 (예: `useSettlementModal`)
- **컴포넌트**: 모달, 폼, 버튼 등 UI 컴포넌트
- **API 파일**: API 호출 코드 (예: `api.등록전`, `api.검수중`)
- **타입 정의**: TypeScript 타입/인터페이스
- **유사 구현체**: 비슷한 기능의 참고 코드

#### B. Figma 디자인 분석 (참고 섹션에 Figma 링크가 있을 경우)

- `mcp__figma-dev-mode-mcp-server__get_code` 도구 사용
- `mcp__figma-dev-mode-mcp-server__get_screenshot` 도구 사용
- 디자인 스펙 요약 (컬러, 사이즈, 레이아웃 등)

#### C. Swagger API 스펙 분석 (참고 섹션에 Swagger 링크가 있을 경우)

- API 엔드포인트, 메서드, 파라미터 확인
- Request/Response 타입 자동 생성 제안

#### D. TDD 기반 TODO 리스트 생성

**우선순위 자동 설정 기준**:

1. 타입 정의
2. Mock 데이터 생성
3. 테스트 케이스 작성 (Red)
4. 구현 (Green)
5. 리팩토링 (Refactor)
6. Storybook 작성 (필요시)

**TODO 예시**:

```markdown
### Todo

- [ ] [타입 정의] SettlementConfirmModalProps 타입 정의
- [ ] [Mock] 정산 정보 상태별 Mock 데이터 생성 (등록전/검수중/반려/완료)
- [ ] [테스트] useSettlementConfirmModal 훅 테스트 작성
  - [ ] 등록전 상태 모달 렌더링 테스트
  - [ ] 검수중 상태 모달 렌더링 테스트
  - [ ] 반려 상태 모달 렌더링 + 이전 값 유지 테스트
  - [ ] 완료 상태 모달 렌더링 테스트
- [ ] [구현] useSettlementConfirmModal 훅 구현
  - [ ] 상태별 분기 로직 구현
  - [ ] 모달 open/close 로직 구현
  - [ ] API 호출 로직 연동
- [ ] [테스트] SettlementConfirmModal 컴포넌트 테스트 작성
  - [ ] 각 상태별 UI 렌더링 테스트
  - [ ] 버튼 클릭 이벤트 테스트
  - [ ] 모달 닫기 동작 테스트
- [ ] [구현] SettlementConfirmModal 컴포넌트 구현
- [ ] [리팩토링] 코드 중복 제거 및 타입 개선
- [ ] [Storybook] SettlementConfirmModal 스토리 작성 (선택)
- [ ] [통합] 기존 페이지에 Hook 통합
- [ ] [E2E] 전체 플로우 수동 테스트
```

### 5️⃣ Notion 백로그 업데이트

`mcp__notionMCP__notion-update-page` 도구를 사용하여 다음을 추가합니다:

#### A. TODO 섹션 업데이트

```markdown
command: insert_content_after
selection_with_ellipsis: "### Todo..."
new_str: "[위에서 생성한 체크리스트 전체]"
```

#### B. 참고 섹션 업데이트

```markdown
command: insert_content_after
selection_with_ellipsis: "### 참고..."
new_str: "
#### 🔄 재사용 가능 공통 코드

**발견된 코드**:
- [Hook] src/hooks/common/useModal.ts
  - 기능: 모달 상태 관리 (open/close)
  - 적용: ✅ 그대로 사용 가능
- [Component] src/components/common/ConfirmModal/index.tsx
  - 기능: 기본 확인 모달 UI
  - 적용: ⚠️ 커스터마이징 필요

**적용 계획**:
1. useModal을 import하여 기본 open/close 로직 처리
2. 상태별 분기 로직만 추가 구현
3. 기존 테스트 케이스 참고하여 테스트 작성

**예상 개발 시간 단축**: 약 30% (공통 로직 재사용)

#### 🔗 관련 파일

- [기존 Hook] src/hooks/useSettlementModal.ts
- [API 파일] src/api/settlement.ts
- [타입 정의] src/types/settlement.ts

#### 📁 생성 예정 파일 경로

- Hook: `src/hooks/useSettlementConfirmModal.ts`
- 컴포넌트: `src/components/Settlement/ConfirmModal/index.tsx`
- 테스트: `src/hooks/useSettlementConfirmModal.test.tsx`
- 스토리북: `src/components/Settlement/ConfirmModal/ConfirmModal.stories.tsx`

#### 🎨 Figma 디자인 스펙

- [Figma 링크] {링크}
- 주요 스펙: [자동 생성된 요약]

#### 🌐 API 스펙

- 엔드포인트: POST /api/v2/settlement/confirm
- Request 타입: SettlementConfirmRequest
- Response 타입: SettlementConfirmResponse

#### 💡 참고 구현체

- 유사 모달: src/components/Payment/ConfirmModal
- 유사 Hook: src/hooks/usePaymentModal.ts
"
```

### 6️⃣ 사용자 확인 및 코드 작성 시작

업데이트된 내용을 사용자에게 보여주고 확인을 받습니다:

```text
✅ Notion 백로그가 업데이트되었습니다!

📌 생성된 브랜치: GBIZ-20629-settlement-info-confirm-modal-hook
📌 워크트리 경로: worktrees/GBIZ-20629-settlement-info-confirm-modal-hook/

📋 TODO 리스트가 추가되었습니다 (10개 항목, TDD 기반)
🔗 관련 파일 및 참고 자료가 정리되었습니다

이제 코드 작성을 시작하시겠습니까? (Yes/No)
- Yes: 첫 번째 TODO부터 작업 시작
- No: 사용자가 직접 검토 후 요청
```

---

## 🔧 프로젝트 규칙 준수

작업 시 다음 문서의 규칙을 반드시 따릅니다:

- **공통 컴포넌트/Hook 가이드**: [.docs/conventions/COMMON_COMPONENTS_HOOKS_GUIDE.md](/.docs/conventions/COMMON_COMPONENTS_HOOKS_GUIDE.md)
- **브랜치 전략**: [.docs/conventions/BRANCH_STRATEGY.md](/.docs/conventions/BRANCH_STRATEGY.md)
- **React 컨벤션**: [.docs/conventions/REACT_CONVENTIONS.md](/.docs/conventions/REACT_CONVENTIONS.md)
- **단위 테스트 규칙**: [.docs/conventions/UNIT_TESTING_RULES.md](/.docs/conventions/UNIT_TESTING_RULES.md)
- **커밋 컨벤션**: [.docs/conventions/COMMIT_CONVENTION.md](/.docs/conventions/COMMIT_CONVENTION.md)
- **스토리북 규칙**: [.docs/conventions/STORYBOOK_RULES.md](/.docs/conventions/STORYBOOK_RULES.md)
- **UI/스타일링 규칙**: [.docs/conventions/UI_STYLING_RULES.md](/.docs/conventions/UI_STYLING_RULES.md)
---

## 📌 중요 체크리스트

작업 수행 전 반드시 확인:

- [ ] Notion 문서에서 GBIZ-ID가 정확히 추출되었는가?
- [ ] 브랜치명이 영어로 올바르게 번역되었는가?
- [ ] TODO 리스트가 TDD 순서로 우선순위가 매겨졌는가?
- [ ] 관련 파일이 모두 검색되었는가?
- [ ] Figma/Swagger 링크가 처리되었는가?
- [ ] Notion 백로그가 올바르게 업데이트되었는가?
- [ ] 사용자 확인을 받았는가?

---

## 🚀 시작하기

**대화 예시**:

```text
User: /generate-backlog-branch

Claude: Notion 백로그 URL을 알려주세요.

User: https://www.notion.so/0909/CRM-Front-hook-28048de8e0ea80718ff0f338c696da9e

Claude:
[문서 분석 중...]

✅ 분석 완료!
- GBIZ-ID: GBIZ-20629
- 작업 제목: [CRM][Front] 정산 정보 컨펌 모달 hook 구현
- 브랜치명 (제안): GBIZ-20629-settlement-info-confirm-modal-hook

워크트리를 생성하시겠습니까? (Yes/No)
```

---

이제 이 커맨드를 실행하면 Notion 백로그를 기반으로 브랜치 생성부터 TDD 작업 계획까지 자동화됩니다!

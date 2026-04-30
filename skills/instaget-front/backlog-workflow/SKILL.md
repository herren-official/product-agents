---
name: instaget-front-backlog-workflow
description: 노션 백로그 생성부터 브랜치, 커밋, PR, 백로그 업데이트까지 전체 워크플로우 자동화
---

# 노션 백로그 워크플로우 (인스타겟 웹)

노션 백로그 생성 → 브랜치 생성 → 변경사항 커밋 → PR 생성 → 백로그 업데이트까지 전체 개발 사이클을 자동화합니다.

## 사용법

```bash
/instaget-front-backlog-workflow                    # 전체 워크플로우 실행
/instaget-front-backlog-workflow "작업 내용 설명"     # 작업 내용과 함께 실행
```

## 전체 워크플로우

### Step 1: 노션 백로그 생성

브랜다즈팀 제품 백로그 DB에 새 백로그를 생성한다.

#### 필수 속성

- **이름**: 명확하고 검색 가능한 제목
- **상태**: 초기값 "백로그" 또는 "할 일"
- **유형**: 작업 / 버그 / 데이터추출 중 선택
- **우선순위**: 상 / 중 / 하
- **플랫폼**: Frontend
- **서비스**: 인스타겟
- **개발 필요**: 예
- **에픽**: 관련 에픽 연결
- **작업자**: 담당자 할당

#### 내용 작성 구조

```markdown
## **작업내용**
### 내용
- 구체적인 요구사항
- 기술적 구현 방향
- 비즈니스 목표

### 참고
- 관련 문서 링크
- 디자인 파일
- 기술 스펙

---
## TT
### Todo
- [ ] 구체적인 작업 항목
- [ ] 테스트 작성
- [ ] 문서 업데이트

### Test Case
#### Happy Path
- 정상 동작 시나리오

#### Exception Cases
- 예외 상황 처리
```

### Step 2: 백로그 ID 확인

- 생성된 백로그에서 IQLX-XXXX ID를 자동 추출
- 사용자에게 ID 확인

### Step 3: 브랜치 생성 및 체크아웃

```bash
# 브랜치 네이밍 규칙: IQLX-XXXX-타입-설명
git checkout -b IQLX-XXXX-feat-feature-name
```

**브랜치 네이밍 규칙:**
- 형식: `IQLX-[백로그번호]-[타입]-[설명]`
- 타입: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `style`
- 설명: kebab-case, 2-4단어, 간결하게
- 50자 이내 권장

### Step 4: 변경사항 커밋

`instaget-front-create-commit` 스킬과 동일한 규칙을 따른다:

- 파일별로 분리하여 작은 단위 커밋
- 커밋 메시지 한글로 자동 생성
- 형식: `type(IQLX-XXXX): 한글 설명`

### Step 5: PR 생성

`instaget-front-create-pr` 스킬과 동일한 규칙을 따른다:

- 베이스 브랜치: 사용자에게 확인
- 리뷰어: marty404 자동 할당
- 담당자: charlie12-21 자동 할당
- PR 제목/본문 자동 생성

### Step 6: 백로그 업데이트

PR 생성 후 노션 백로그에 작업 내용을 정리한다.

1. **IQLX-XXXX로 노션 검색** → `notion-search`
2. **백로그 페이지 fetch** → `notion-fetch`
3. **작업 내용 업데이트** → `notion-update-page`
   - PR Summary/Changes 내용 반영
   - Todo 항목 체크
   - 기존 내용 보존하며 보완

#### 업데이트 시 금지 사항
- ❌ 파일명/함수명 나열 (→ 기능 레벨로 설명)
- ❌ Git 관련 정보 (커밋 해시, 브랜치명, PR 번호)
- ❌ 상태/날짜 속성 변경
- ❌ 기존 내용 삭제

## 결과 보고

```
- 노션 백로그 생성 완료
- 백로그 ID: IQLX-XXXX
- 브랜치 IQLX-XXXX-feat-xxx 생성
- 변경사항 N개 커밋 완료
- PR 생성: https://github.com/.../pull/XXX
- 백로그 업데이트 완료
- 백로그 링크: https://notion.so/...
```

## 주의사항

- 각 단계에서 실패 시 사용자에게 알리고 재시도 또는 수동 진행 안내
- 백로그 상태는 자동으로 변경하지 않음 (사용자가 직접 관리)
- 브랜치명 전체는 50자 이내 권장
- 패키지 매니저는 yarn 사용

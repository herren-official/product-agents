---
name: crm-ios-pr
description: GitHub Pull Request를 생성합니다. 변경사항을 분석하고 PR 템플릿에 맞게 작성합니다. PR, 풀리퀘, PR 만들어줘 요청 시 사용.
allowed-tools: Read, Grep, Glob, Bash
---

# PR (Pull Request)

GitHub PR을 생성하는 스킬입니다.

## 실행 알림
이 스킬이 실행되면 가장 먼저 "[crm-ios-pr] 스킬이 실행되었습니다."를 출력할 것

## 실행 프로세스

### 1단계: 사전 확인

```bash
# 현재 브랜치 확인
git branch --show-current

# 커밋되지 않은 변경사항 확인
git status --porcelain

# 원격 동기화 상태 확인
git fetch origin
git status -sb
```

### 2단계: GBIZ 번호 추출

```bash
# 브랜치명에서 GBIZ 번호 추출
git branch --show-current | grep -oE "GBIZ-[0-9]+"
```

### 3단계: 커밋 히스토리 분석

```bash
# develop과의 차이 분석
git log origin/develop..HEAD --oneline

# 변경된 파일 목록
git diff origin/develop...HEAD --name-status
```

### 4단계: Base 브랜치 확인 (필수!)

```
"[호칭], PR을 생성하기 전에 base 브랜치를 확인해주세요.

현재 브랜치: {현재 브랜치명}

어느 브랜치로 머지하시겠습니까?
- develop (기본)
- 다른 브랜치 지정"
```

### 5단계: 작업 내용 분석 및 Label 추론

변경 파일 타입별 분류:
| 파일 타입 | 작업 내용 |
|----------|----------|
| Router | API 엔드포인트 변경 |
| Repository | 데이터 처리 로직 변경 |
| ViewModel | 비즈니스 로직 변경 |
| View | UI 변경 |
| Test | 테스트 추가/수정 |

#### Label 매핑 규칙

커밋 타입과 변경 파일을 기반으로 label을 추론한다.

| 조건 | Label |
|------|-------|
| View, Controller, UI 파일 변경 | `:framed_picture: UI` |
| feat 타입 커밋 포함 | `:star: Feature` |
| fix 타입 커밋 포함 | `:lady_beetle: BugFix` |
| refactor 타입 커밋 포함 | `:hammer: Refactor` |
| test 타입 커밋 포함 | `🧪 TestCode` |
| project/config 파일만 변경 | `:gear: Setting` |
| doc 타입 커밋 포함 | `📄 Document` |
| 파일 삭제 포함 (D status) | `🗑️ FileDeleted` |

#### 주의: Label 이름의 이모지 형식

GitHub label 이름에 shortcode(`:star:`)와 유니코드(`🧪`) 형식이 혼재되어 있다.
`gh crm-ios-pr create --label` 옵션에는 **실제 GitHub에 등록된 정확한 이름**을 사용해야 한다.

- shortcode 형식: `:star:`, `:lady_beetle:`, `:hammer:`, `:gear:`, `:framed_picture:`
- 유니코드 형식: `🧪`, `📄`, `🗑️`, `⛔️`, `📥`

**유니코드로 변환하면 안 되는 label**: `:star: Feature` → `⭐ Feature` (X)

#### 추론 규칙
- **복수 label 가능**: 조건에 해당하는 label을 모두 추가
- **우선순위**: 커밋 타입 기반 > 파일 타입 기반
- **TestCode label**: test 타입 커밋이 있거나, Tests 파일이 변경된 경우 추가
- **Feature + UI 조합 가능**: 새 기능이면서 UI 작업인 경우 둘 다 추가

### 6단계: 확인사항 초안 작성 및 검토 요청

5단계에서 추론한 label을 확인사항과 함께 표시한다.

```
"[호칭], PR 확인사항을 검토해주세요.

## 확인 사항
- [ ] {자동 생성된 확인사항}
- [ ] {파일 타입별 확인사항}

### 작업 확인 경로
- {자동 추론된 경로}

## Label
- {추론된 label 목록}

수정이 필요하면 알려주세요.

참고 문서 링크가 필요하다면 알려주세요:
- 노션 링크
- Figma 링크
- API 문서 링크"
```

### PR 생성 전 체크리스트

자동으로 다음 사항 확인:
- [ ] 모든 변경사항 커밋 완료
- [ ] 원격 저장소 push 완료
- [ ] 충돌 없음 확인

### 7단계: 원격 저장소 푸시

```bash
git push -u origin $(git branch --show-current)
```

### 8단계: PR 생성

5단계에서 추론한 label을 `--label` 옵션으로 추가한다.
label 개수는 동적이며, 추론된 label마다 `--label` 옵션을 반복 추가한다.
추론된 label이 없으면 `--label` 옵션을 생략한다.

```bash
# label이 있는 경우 (개수만큼 --label 반복)
gh crm-ios-pr create \
  --base {사용자 확인 base 브랜치} \
  --title "[GBIZ-번호] 제목" \
  --label "{label1}" --label "{label2}" ... \
  --body "$(cat <<'EOF'
## 작업 사항
- 작업 내용 1
- 작업 내용 2

## 확인 사항
- [ ] 확인사항 1
- [ ] 확인사항 2

### 작업 확인 경로
1. 앱 실행 > 로그인
2. 하단 탭 > 해당 탭 선택
3. ...

## 기타
추가 설명

## 참고
- 노션 일감카드: GBIZ-XXXXX
EOF
)"
```

## 확인사항 작성 가이드

### 작업 타입별 확인사항

**Router/API 변경:**
```
- [ ] API 엔드포인트가 정상 호출되는지 확인
- [ ] 요청 파라미터가 올바르게 전달되는지 확인
- [ ] 응답 데이터가 정상적으로 파싱되는지 확인
```

**ViewModel 변경:**
```
- [ ] 화면 진입 시 초기 데이터 로드 확인
- [ ] 사용자 액션에 따른 상태 변화 확인
- [ ] 에러 처리 및 로딩 상태 확인
```

**UI 변경:**
```
- [ ] 디자인 시안과 일치하는지 확인
- [ ] 다크모드에서 정상 표시되는지 확인
```

**테스트 추가:**
```
- [ ] 추가된 테스트가 모두 통과하는지 확인
- [ ] 기존 테스트에 영향 없는지 확인
```

### 좋은 예시 ✅
```
- [ ] 예약 상세 > 메모 입력 시 500자 초과하면 에러 메시지 표시 확인
- [ ] 고객 목록 > 검색 > 전화번호로 검색 시 하이픈 없이도 검색되는지 확인
```

### 나쁜 예시 ❌
```
- [ ] 기능이 잘 동작하는지 확인
- [ ] 버그가 수정되었는지 확인
```

## 작업 확인 경로 예시

### 좋은 예시 ✅
```
1. 앱 실행 > 로그인
2. 하단 탭 > 예약 탭 선택
3. 예약 목록에서 아무 예약 선택
4. 상세 화면 > 우측 상단 수정 버튼 탭
```

### 나쁜 예시 ❌
```
- 예약 화면에서 확인
- 해당 기능으로 이동
```

## 금지 사항

- ⛔ "Generated with Claude Code" 절대 금지
- ⛔ "Co-Authored-By" 절대 금지
- ⛔ AI가 작성했다는 언급 절대 금지
- ⛔ 이모지 사용 금지
- ✅ 순수한 PR 내용만 작성

## 참조 문서

- Git 가이드: `.docs/GIT_GUIDE.md`
- 호칭: `CLAUDE.local.md`

---
name: b2b-android-review-pr
description: "PR 코드 리뷰 수행. Use when: PR 리뷰, 리뷰해줘, 코드 리뷰, PR 검토"
argument-hint: "[PR번호|crm|b2c|all] (생략 시 현재 레포의 리뷰 가능한 PR 목록)"
allowed-tools: ["bash", "read", "grep", "glob"]
---

# PR 코드 리뷰

CLAUDE.md와 프로젝트 컨벤션 기준으로 PR을 리뷰합니다.
자가 리뷰(변경 코드 품질 검토/수정)는 `/simplify`를 사용하세요.

!gh api user --jq '.login'

리뷰 대상: $ARGUMENTS

## 인자 처리

| 인자 | 동작 |
|------|------|
| 없음 / `b2c` | `herren-official/gongbiz-b2c-android`에서 리뷰할 PR 목록 |
| PR 번호 | 현재 레포에서 해당 PR 직접 리뷰 |
| `crm` | `herren-official/gongbiz-crm-android`에서 리뷰할 PR 목록 |
| `all` | 두 레포 모두에서 리뷰할 PR 목록 |

## PR 탐색

### 레포 매핑
| 인자 | 레포 |
|------|------|
| 없음 / `b2c` | `herren-official/gongbiz-b2c-android` |
| `crm` | `herren-official/gongbiz-crm-android` |
| `all` | 두 레포 모두 |
| 숫자 | 현재 레포에서 해당 PR 번호 |

### PR 필터링
```bash
gh pr list --repo {repo} --state open --json number,title,author,assignees,createdAt,headRefName,labels
```
- `state = open`
- `assignees`에 `dana-herren`이 **포함되지 않은** PR만
- 최신순 정렬

### PR 목록 표시
```
| # | 제목 | 작성자 | 브랜치 | 라벨 | 생성일 |

리뷰할 PR 번호를 알려주세요.
```

## PR 정보 수집
```bash
gh pr view {number} --repo {repo} --json title,body,author,files,additions,deletions,commits,baseRefName,headRefName,labels,reviewRequests
gh pr diff {number} --repo {repo}
gh api repos/{repo}/pulls/{number}/comments
```

### 변경사항 분류
1. **파일 유형**: Screen, ViewModel, Contract, Navigation, Repository/UseCase, 테스트, 설정, 문서
2. **변경 규모**: Small(~100줄), Medium(100~300줄), Large(300줄+, 분할 PR 권장 확인)

## 리뷰 체크리스트

### 1. 아키텍처 패턴
- [ ] ViewModel이 `BaseIntentViewModel<BaseUiState>` 상속하는가?
- [ ] UI 이벤트를 public 메서드로 처리하는가?
- [ ] 상태 업데이트에 `reduceState` / `reduceSuccessState<T>` 사용하는가?
- [ ] API 호출에 `apiFlow` / `slackFlow` 패턴을 사용하는가?
- [ ] SideEffect를 `postSideEffect { }` 로 전달하는가?

### 2. 네이밍 컨벤션
- [ ] ViewModel: `{Feature}ViewModel`
- [ ] Screen: `{Feature}Screen.kt` 안에 `{Feature}Route` + `{Feature}Screen`
- [ ] UseCase: `{Action}{Entity}UseCase`
- [ ] Repository: 인터페이스 `{Domain}Repository`, 구현체 `{Domain}RepositoryImpl`

### 3. 디자인 시스템 사용
- [ ] `B2CText`, `RectangleButton` 등 디자인 시스템 컴포넌트 사용
- [ ] 색상/타이포/Shape 시스템 사용 (하드코딩 X)
- [ ] 리플 제거: `NoRippleInteractionSource`
- [ ] 화면 수평 패딩 `20.dp`, 최소 터치 영역 `48.dp`

### 4. 에러 처리
- [ ] API 호출에 에러 핸들링이 있는가?
- [ ] 로딩/에러/성공 상태를 모두 처리하는가?

### 5. 성능
- [ ] `remember` / `derivedStateOf` 활용하는가?
- [ ] `LazyColumn`에 `key` 파라미터 설정되어 있는가?

### 6. 보안
- [ ] API 키 하드코딩 없는가?
- [ ] 민감한 데이터 로그 출력 없는가?

### 7. 코드 품질
- [ ] 불필요한 import / TODO / 디버그 코드 없는가?
- [ ] 500줄 이상이면 PR 분할 권장

## PRD 기반 비즈니스 로직 검증
- `.docs/prd/{관련모듈}.md` 참조
- 변경된 로직이 PRD의 비즈니스 규칙과 일치하는지 확인

## 관련 테스트 확인
- 변경된 ViewModel에 대한 테스트 파일 존재 여부
- 새로 추가된 public 메서드에 대한 테스트 케이스 존재 여부

## 출력 형식
```
## PR #{number} 코드 리뷰

### PR 정보
- **제목**: {title}
- **작성자**: {author}
- **브랜치**: {head} → {base}
- **변경**: +{additions} -{deletions} ({files}개 파일)

### 변경 파일 분류
| 유형 | 파일 | 변경 |

### 리뷰 결과
#### 잘 된 점
#### 개선 제안
| 파일:라인 | 이슈 | 제안 |
#### 수정 필요
| 파일:라인 | 이슈 | 이유 |
#### 비즈니스 로직 확인
#### 테스트 확인

### 총평
- 승인 / 수정 요청 / 코멘트만
```

## 리뷰 코멘트 작성 (선택)
사용자 확인 후 GitHub에 리뷰 코멘트 작성:
```bash
gh pr review {number} --repo {repo} --approve --body "LGTM"
gh pr review {number} --repo {repo} --request-changes --body "수정 필요 사항"
```
**중요**: 리뷰 코멘트 작성 전 반드시 사용자 확인을 받을 것.

## 리뷰 기준 문서
- `CLAUDE.md`, `.docs/conventions/project-convention.md`, `.docs/design_system.md`
- `.docs/conventions/test-convention.md`, `.docs/prd/`

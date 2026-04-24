---
name: b2c-android-ship
description: "코드 정리 → 테스트 → 커밋 → 빌드 체크 → PR 생성까지 한번에. Use when: 작업 마무리, PR까지 해줘, ship, 올려줘, 다 끝났어"
argument-hint: "[target-branch|GBIZ-NNNNN] [--no-test]"
allowed-tools: ["bash", "read", "write", "edit", "grep", "glob", "mcp__notionMCP__notion-search", "mcp__notionMCP__notion-fetch", "mcp__notionMCP__notion-update-page"]
---

# Ship — 코드 정리부터 PR 생성까지

작업 완료 후 PR 생성까지의 전체 워크플로우를 순차 실행합니다.

!git branch --show-current
!git status --porcelain
!git diff --stat

인자: $ARGUMENTS

## 인자 파싱

- `--no-test`: 테스트 코드 작성 단계(Step 2)를 스킵
- 그 외 인자: create-pr에 전달 (target-branch 또는 GBIZ 번호)

## 워크플로우 개요

**기본 (테스트 포함)**:
```
Step 1: /create-commit — 코드 정리(simplify) + 커밋
Step 2: unit-test      — 변경된 ViewModel/UseCase 테스트 생성/수정 + 커밋
Step 3: check-build    — 빌드/린트/테스트 검증
Step 4: /create-pr     — PR 자동 생성 (노션 연동)
```

**`--no-test` 옵션 사용 시**:
```
Step 1: /create-commit — 코드 정리(simplify) + 커밋
Step 2: check-build    — 빌드/린트/테스트 검증
Step 3: /create-pr     — PR 자동 생성 (노션 연동)
```

각 단계 실패 시 중단하고 원인을 안내합니다.
사용자가 단계를 건너뛰고 싶으면 요청에 따라 스킵 가능합니다.

> `/create-commit`에 코드 정리(simplify)가 포함되어 있으므로 별도 실행 불필요

---

## Step 1: 커밋 (create-commit)

**필수 참조**: `.docs/commit-convention.md`

1. 변경사항 분석 및 논리적 단위로 분류
2. 커밋 컨벤션에 맞는 메시지 생성:
   - `<type>: <subject>` (한글, 50자 이내)
   - Claude 서명/Co-Author/이모지 금지
3. 논리적 단위별 개별 커밋
4. 민감 파일 제외 (`.env`, `apikey.properties`)
5. 커밋 결과 표시

### 이미 커밋된 경우
- staged/unstaged 변경사항이 없으면 스킵

---

## Step 2: 테스트 코드 작성 (unit-test) — `--no-test` 시 스킵

변경된 파일에서 ViewModel/UseCase를 감지하여 테스트 코드를 자동 생성/수정합니다.

**필�� 참조**: `.docs/conventions/test-convention.md`, `.docs/test-workflow.md`

1. **변경 대상 감지**:
   ```bash
   git diff --name-only HEAD~1..HEAD -- '*.kt'
   ```
   - 변경된 파일에서 ViewModel, UseCase 클래스 추출
   - 테스트 대상이 없으면 스킵

2. **기존 테스트 확인**:
   - 테스트 파일이 있으면 → **수정 모드** (기존 테스트 실행 → 실패 수정)
   - 테스트 파일이 없으면 → **생성 모드** (테스트 생성 → 실행 → 실패 수정)

3. **테스트 생성/수정** (`unit-test` 에이전트 위임):
   - `MockWebServerTestViewModel` 상속 패턴 적용
   - 생성 → 실행 → 실패 수정 → 재실행 (최대 3회 반복)
   - 전체 통과까지 자동 수행

4. **테스트 코드 커밋**:
   - 테스트 파일만 별도 커밋: `test: {ClassName} 유닛 테스트 작성`
   - `.docs/viewmodel-test-status.md` 업데이트 포함

### 실패 시
- 3회 수정 후에도 실패하는 테스트가 있으면 사용자에게 안내
- "테스트 실패를 무시하고 계속 진행할까요?" 확인

---

## Step 3: 빌드 체크 (check-build) — `--no-test` 시 Step 2

1. 변경된 모듈 감지 (`git diff`에서 모듈 경로 추출)
2. **컴파일 체크**:
   ```bash
   ./gradlew assembleDevDebug --continue
   ```
3. **린트 체크** (변경 모듈만):
   ```bash
   ./gradlew :{module}:lintDevDebug --continue
   ```
4. **테스트 실행** (테스트 파일 있는 모듈만):
   ```bash
   ./gradlew :{module}:testDevDebugUnitTest --continue
   ```
5. 결과 요약:

```
| 항목 | 결과 | 상세 |
|------|------|------|
| 컴파일 | PASS/FAIL | {소요 시간} |
| 린트 | PASS/WARN/FAIL | Error {N}, Warning {N} |
| 테스트 | PASS/FAIL | {성공}/{실패}/{스킵} |
```

### 실패 시
- **컴파일 실패**: 에러 원인 안내, 워크플로우 중단
- **린트 Error**: 에러 원인 안내, 워크플로우 중단
- **린트 Warning만**: 사용자에게 "Warning 있지만 계속 진행할까요?" 확인
- **테스트 실패**: 실패 테스트 안내, 사용자에게 "계속 진행할까요?" 확인

---

## Step 4: PR 생성 (create-pr) — `--no-test` 시 Step 3

**필수 참조**: `.docs/pr-convention.md`

1. 브랜치명에서 GBIZ 번호 추출
2. Base 브랜치 결정:
   - `$ARGUMENTS` 있으면 해당 브랜치/GBIZ 번호 사용
   - 없으면 부모 브랜치 자동 탐색 → 실패 시 `dev`
3. Notion 카드 검색 (GBIZ 번호)
4. PR 제목/본문 자동 생성
5. **사용자 확인** (필수): 제목, base, 본문, label 미리보기
6. 기존 PR 확인 → Push → PR 생성
7. Label 자동 설정 (브랜치 키워드 기반)
8. **Notion 카드 3곳 업데이트**:
   - GitHub 풀 리퀘스트 속성
   - 내용 섹션
   - 참고 섹션

---

## 최종 결과

```
## Ship 완료

### 워크플로우 결과
| 단계 | 결과 |
|------|------|
| 커밋 (simplify 포함) | {커밋 N개 생성} |
| 테스트 코드 | {N개 ViewModel 테스트 생성/수정} 또는 스킵 |
| 빌드 체크 | {PASS / WARNING} |
| PR 생성 | PR #{number} |

### PR
- URL: {PR URL}
- 제목: [GBIZ-XXXXX] {제목}
- Base: {base-branch}
```

## 사용 예시
```bash
/ship                    # 전체 워크플로우 (테스트 포함, base 자동 탐색)
/ship dev                # dev를 base로 PR 생성 (테스트 포함)
/ship --no-test          # 테스트 코드 작성 없이 PR
/ship dev --no-test      # dev를 base로, 테스트 스킵
/ship GBIZ-19448         # GBIZ-19448 브랜치를 base로
```

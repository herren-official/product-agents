---
name: b2c-android-ship
description: "코드 정리 → 테스트 → 커밋 → 빌드 체크 → PR 생성까지 한번에. Use when: 작업 마무리, PR까지 해줘, ship, 올려줘, 다 끝났어"
argument-hint: "[target-branch|GBIZ-NNNNN] [--no-test]"
allowed-tools: ["bash", "read", "write", "edit", "grep", "glob", "mcp__notionMCP__notion-search", "mcp__notionMCP__notion-fetch", "mcp__notionMCP__notion-update-page"]
---

# Ship — 코드 정리부터 PR 생성까지

작업 완료 후 PR 생성까지의 전체 워크플로우를 순차 실행합니다.

!.claude/scripts/git-context.sh

인자: $ARGUMENTS

## 인자 파싱

- `--no-test`: 테스트 코드 작성 단계(Step 2)를 스킵
- 그 외 인자: create-pr에 전달 (target-branch 또는 GBIZ 번호)

## 워크플로우 개요

**기본 (테스트 포함)**:
```
Step 1: /create-commit — 코드 정리(simplify) + 커밋
Step 2: unit-test      — 변경된 ViewModel/UseCase 테스트 생성/수정 + 커밋
Step 3: /create-pr     — check-build 자동 호출 (컴파일 + 단위 테스트) + PR 생성 (노션 연동)
```

**`--no-test` 옵션 사용 시**:
```
Step 1: /create-commit — 코드 정리(simplify) + 커밋
Step 2: /create-pr     — check-build 자동 호출 + PR 생성
```

각 단계 실패 시 중단하고 원인을 안내합니다.
사용자가 단계를 건너뛰고 싶으면 요청에 따라 스킵 가능합니다.

> 빌드/테스트 검증은 `/create-pr` 안의 check-build 강제 호출로 단일화. ship 단독에서 별도 호출 안 함 (중복 방지).
> 코드 정리(simplify)는 `/create-commit` Step 0 에서 **Simplify Targets ≥ 1 일 때 강제 호출** (3 에이전트 병렬). 트리거 대상: Kotlin + strings.xml + Mock JSON. md/docs/drawable 만 변경 시 스킵.

---

## Step 1: 커밋 (create-commit)

**필수 참조**: `.docs/conventions/commit-convention.md`. 상세는 `/create-commit` 위임 (단일 진실 소스).

1. 변경사항 분석 및 논리적 단위로 분류
2. 커밋 컨벤션에 맞는 메시지 생성:
   - `<type>: <subject>` (한글, 50자 이내)
   - Claude 서명/Co-Author/이모지 금지 (**SA-COMMIT-002 commit-msg hook 자동 차단**)
3. 논리적 단위별 개별 커밋
4. 민감 파일 제외 (`.env`, `apikey.properties`)
5. 커밋 결과 표시

### 이미 커밋된 경우
- staged/unstaged 변경사항이 없으면 스킵

---

## Step 2: 테스트 코드 작성 (unit-test) — `--no-test` 시 스킵

변경된 파일에서 ViewModel/UseCase를 감지하여 테스트 코드를 자동 생성/수정합니다.

**필수 참조**: `.docs/conventions/test-convention.md`, `.docs/test-workflow.md`

1. **변경 대상 감지 + 기존 테스트 확인** (결정적 스크립트):
   ```bash
   .claude/scripts/test-targets.sh HEAD~1
   ```
   출력에 각 대상의 `수정 모드` / `생성 모드` 가 결정적으로 표기됨. "테스트 대상 없음" 이면 스킵.

2. **테스트 생성/수정** (`unit-test` 에이전트 위임):
   - `Agent` 도구로 1회 호출:
     - `subagent_type`: `unit-test`
     - `description`: `Unit tests for changed ViewModels/UseCases`
     - `prompt`: `변경 대상(test-targets.sh 출력) 의 ViewModel/UseCase 테스트 생성→실행→실패 수정→통과까지 자율 수행. MockWebServerTestViewModel 상속 패턴.`
   - 생성 → 실행 → 실패 수정 → 재실행 (최대 3회 반복)
   - 전체 통과까지 자동 수행

3. **테스트 코드 커밋**:
   - 테스트 파일만 별도 커밋: `test: {ClassName} 유닛 테스트 작성`
   - `.docs/viewmodel-test-status.md` 업데이트 포함

### 실패 시
- 3회 수정 후에도 실패하는 테스트가 있으면 사용자에게 안내
- "테스트 실패를 무시하고 계속 진행할까요?" 확인

---

## Step 3: PR 생성 (create-pr) — `--no-test` 시 Step 2

`/create-pr` 스킬에 위임 (단일 진실 소스, 상세는 [create-pr/SKILL.md](../create-pr/SKILL.md) 참조).

`/create-pr` 안에서 **Step 0 으로 check-build agent 자동 호출** — 컴파일 + 단위 테스트 검증 통과해야 PR 생성. 실패 시 PR 생성 안 함, 사용자 fix 후 재호출.

핵심 흐름:
0. **check-build agent 자동 호출** (컴파일 + 단위 테스트) — 실패 시 즉시 중단
1. 브랜치명에서 GBIZ 번호 추출
2. Base 브랜치 결정 (`$ARGUMENTS` 있으면 그대로, 없으면 부모 자동 탐색 → 실패 시 `develop`)
3. Notion 카드 검색 → PR 제목/본문 자동 생성 → 사용자 확인 (필수)
4. Push + PR 생성 + label 자동 설정
5. Notion 카드 3곳 업데이트 (속성/내용/참고)

---

## 최종 결과

```
## Ship 완료

### 워크플로우 결과
| 단계 | 결과 |
|------|------|
| 커밋 (simplify 포함) | {커밋 N개 생성} |
| 테스트 코드 | {N개 ViewModel 테스트 생성/수정} 또는 스킵 |
| 빌드 체크 (create-pr 안) | {컴파일 PASS + 단위 테스트 N 통과} |
| PR 생성 | PR #{number} |

### PR
- URL: {PR URL}
- 제목: [GBIZ-XXXXX] {제목}
- Base: {base-branch}
```

## 사용 예시
```bash
/ship                    # 전체 워크플로우 (테스트 포함, base 자동 탐색)
/ship develop            # develop 을 base로 PR 생성 (테스트 포함)
/ship epic-ai/main       # epic accumulator main 을 base 로 (stack PR)
/ship --no-test          # 테스트 코드 작성 없이 PR
/ship develop --no-test  # develop 을 base로, 테스트 스킵
/ship GBIZ-19448         # GBIZ-19448 브랜치를 base로
```

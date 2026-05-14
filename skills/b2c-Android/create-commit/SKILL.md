---
name: b2c-android-create-commit
description: "현재 staged/unstaged 파일들을 분석하여 커밋 메시지 자동 생성 및 커밋. Use when: 커밋 해줘, 커밋 메시지 생성, 변경사항 커밋"
argument-hint: "[additional-context]"
allowed-tools: ["bash", "read", "write", "edit", "grep", "glob"]
---

# 자동 커밋

변경 코드를 정리(simplify)한 뒤, 프로젝트 커밋 컨벤션에 맞는 커밋 메시지를 생성하고 커밋합니다.

!.claude/scripts/git-context.sh
!.claude/scripts/commit-type.sh

## Step 0: 코드 정리 (simplify) — Simplify Targets ≥ 1 일 때 강제

위 `Simplify Targets` 섹션에 나열된 파일이 1개 이상이면 **반드시 `Skill` 도구로 `simplify` 스킬 호출**. (3 에이전트 병렬: Code Reuse / Code Quality / Efficiency Review)

```
Skill(skill="simplify")
```

**트리거 대상** (`git-context.sh` 가 결정적으로 분류):
- Kotlin / Gradle Kotlin (`*.kt`, `*.kts`)
- `strings.xml` (모든 res/values* 안) — 기존 키 재사용 검출
- Mock JSON (`src/test/resources/`, `src/testFixtures/resources/`) — 기존 mock 재사용 검출

**스킵 조건**:
- Simplify Targets 0개 (md / docs / script / drawable·layout xml / build 설정 만 변경) → **Step 0 스킵**

> pre-commit hook 으로는 LLM 스킬 호출 불가 → 이 SKILL Step 0 에서 강제하는 것이 단일 진실 소스. `/ship` 도 Step 1 에서 이 스킬을 위임하므로 자동 적용.

## 필수 참조
- 커밋 컨벤션: `.docs/conventions/commit-convention.md` — 반드시 먼저 읽고 규칙을 따를 것

## 주의사항
- 커밋 메시지에 Claude 관련 서명·Co-Author·이모지 금지 — **SA-COMMIT-002 commit-msg hook 으로 자동 차단** (`scripts/git-hooks/commit-msg`). `Co-Authored-By:` trailer / `Generated with [Claude Code]` / 이모지 검출 시 reject. 미설치면 `./scripts/install-hooks.sh` 1회 실행 필요
- 위 `⚠ Sensitive Files` 섹션에 나온 파일은 스테이지에서 제외

## Git 처리 전략
1. Staged 파일 우선 커밋
2. 논리적 단위로 분리 (서로 다른 목적의 파일은 별도 커밋)
   - 분리 커밋을 한 뒤에는 각 커밋마다 **다시 `.claude/scripts/commit-type.sh` 호출**해서 type 재판정
3. 개별 파일 추가 (`git add .` 대신)
4. 커밋 메시지 규칙:
   - **type**: 위 `Commit Type 판정` 섹션의 `Auto-detected` 값이 있으면 **그대로 사용** (LLM 이 바꾸지 말 것). 없으면 힌트 참고해 판단
   - **subject**: 한글, 50자 이내, 현재 시제, 마침표 없음

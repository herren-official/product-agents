---
name: b2c-android-create-commit
description: "현재 staged/unstaged 파일들을 분석하여 커밋 메시지 자동 생성 및 커밋. Use when: 커밋 해줘, 커밋 메시지 생성, 변경사항 커밋"
argument-hint: "[additional-context]"
allowed-tools: ["bash", "read", "write", "edit", "grep", "glob"]
---

# 자동 커밋

변경 코드를 정리(simplify)한 뒤, 프로젝트 커밋 컨벤션에 맞는 커밋 메시지를 생성하고 커밋합니다.

!git status --porcelain
!git diff --staged --stat
!git diff --stat

## Step 0: 코드 정리 (simplify)

커밋 전 변경된 파일의 코드 품질을 검토하고 자동 수정합니다.

1. `git diff --name-only`로 변경된 Kotlin 파일 파악
2. 변경 파일을 읽고 검토:
   - 코드 재사용성: 기존 유틸/컴포넌트 활용 가능 여부
   - 코드 품질: 네이밍, 불필요한 코드, 중복
   - 효율성: 불필요한 연산, remember 누락, 성능 이슈
3. 이슈 발견 시 자동 수정 후 변경 내용 요약
4. 수정 없으면 바로 다음 단계로

## 필수 참조
- **커밋 컨벤션**: `.docs/commit-convention.md` — 반드시 먼저 읽고 규칙을 따를 것

## 주의사항
- 커밋 메시지에 Claude 관련 서명이나 Co-Author 정보를 추가하지 마세요
- 이모지나 "Generated with Claude Code" 같은 문구 사용 금지

## 핵심 원칙
1. **작은 단위로 커밋**: 하나의 논리적 변경사항만 포함
2. **명확한 설명**: 무엇을 왜 변경했는지
3. **커밋 분리**: 서로 다른 목적의 파일은 별도 커밋으로 처리

## Git 처리 전략
1. Staged 파일 우선 커밋
2. 논리적 단위로 분리
3. 개별 파일 추가 (`git add .` 대신)
4. 민감 파일 제외 (`.env`, `apikey.properties`, `local.properties`)

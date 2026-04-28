---
name: b2b-backend-codebase
description: 개발 코드베이스로 이동하여 코드 파악 및 개발 작업 수행
---

개발 코드베이스(`gongbiz-crm-b2b-backend`)로 이동하여 코드를 파악하고 개발 작업을 수행하는 세션을 시작한다.

## 세션 시작 절차

1. **작업 디렉토리 이동**: `cd ~/herren-repo/gongbiz-crm-b2b-backend` 로 작업 디렉토리를 변경한다.
2. **개인 규칙 로드**: `~/herren-repo/CLAUDE.md` 파일을 읽어 개인 작업 선호사항과 규칙을 파악한다.
3. **프로젝트 규칙 로드**: `~/herren-repo/gongbiz-crm-b2b-backend/CLAUDE.md` 파일을 읽어 프로젝트 구조, 기술 스택, 컨벤션, 빌드/테스트 명령어 등 개발 규칙을 파악한다.
4. **사용자 지시 대기**: 컨텍스트를 파악한 뒤 사용자에게 어떤 개발 작업을 진행할지 확인한다.

## 작업 규칙

- **CLAUDE.md의 규칙을 항상 준수**한다. 모듈별 Spring Boot 버전, JPA 패키지(`javax.*` vs `jakarta.*`), 패키지 구조 등을 반드시 확인한 후 코드를 작성한다.
- 코드 탐색 시 `Glob`, `Grep`, `Read` 도구를 적극 활용하여 기존 코드 패턴을 먼저 파악한다.
- 커밋 메시지는 `type(GBIZ-XXXXX): 설명` 형식을 따른다.
- 브랜치명은 `GBIZ-XXXXX-description-in-kebab-case` 형식을 따른다.
- 레이어별 책임(Presentation → Application → Domain → Infrastructure)을 준수한다.
- 새 코드 작성 시 해당 모듈의 기존 코드 스타일과 패턴을 따른다.

## 참조 문서

- **프로젝트 구조**: `~/herren-repo/gongbiz-crm-b2b-backend/.docs/project-structure.md`
- **커밋 컨벤션**: `~/herren-repo/gongbiz-crm-b2b-backend/.docs/conventions/commit-convention.md`
- **코드 컨벤션**: `~/herren-repo/gongbiz-crm-b2b-backend/.docs/conventions/code-convention.md`
- **아키텍처 개선안**: `~/herren-repo/gongbiz-crm-b2b-backend/.docs/conventions/architecture-improvement-proposal.md`

## 인자 처리

$ARGUMENTS가 제공된 경우 해당 내용을 코드베이스에서 탐색하거나 관련 개발 작업을 바로 수행한다.

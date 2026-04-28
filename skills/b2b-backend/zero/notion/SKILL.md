---
name: b2b-backend-notion
description: 노션 워크스페이스 탐색 및 로컬 리소스 정리
argument-hint: <검색어 또는 작업 내용>
---

노션 MCP를 활용하여 워크스페이스를 탐색하고 로컬 리소스를 정리하는 세션을 시작한다.

## 세션 시작 절차

1. **로컬 컨텍스트 로드**: `~/claude-resources/notions/claude.md` 파일을 읽어 현재 워크스페이스 정보, 주요 페이지 참조, 도구 사용 권한 등을 파악한다.
2. **사용자 지시 대기**: 컨텍스트를 파악한 뒤 사용자에게 어떤 노션 작업을 진행할지 확인한다.

## 작업 규칙

- **Notion search/fetch는 승인 없이 바로 실행**한다. 매번 사용자 확인을 받지 않는다.
- 노션에서 조회한 내용은 `~/claude-resources/notions/` 하위에 정리하여 로컬 파일로 저장한다.
- 새로운 정보를 파악하면 `~/claude-resources/notions/claude.md`를 업데이트하여 다음 세션에서도 활용할 수 있게 한다.
- gongbiz 프로젝트 관련 내용은 `~/claude-resources/notions/gongbiz/` 폴더에 정리한다.

## 인자 처리

$ARGUMENTS가 제공된 경우 해당 내용을 노션에서 검색하거나 관련 작업을 바로 수행한다.

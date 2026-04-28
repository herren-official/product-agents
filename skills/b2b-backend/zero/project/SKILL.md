---
name: b2b-backend-project
description: 진행중인 프로젝트 현황 확인 및 STATUS.md 업데이트
argument-hint: [update|프로젝트명|update 프로젝트명]
---

현재 진행 중인 프로젝트의 상태를 확인하고 관리한다.

## 프로젝트 컨텍스트 경로

프로젝트별 컨텍스트는 아래 디렉토리에 폴더 단위로 관리된다:

```
~/claude-resources/notions/codebase/
```

각 프로젝트 폴더에는 `STATUS.md`(진행 상태), 설계 문서, 코드 계획 등이 포함된다.

## 실행 절차

### 1. 프로젝트 목록 스캔

`~/claude-resources/notions/codebase/` 하위 폴더를 스캔하여 진행 중인 프로젝트 목록을 파악한다.

### 2. STATUS.md 로드

각 프로젝트 폴더의 `STATUS.md`를 읽어 현재 단계, 완료/미완료 티켓, 남은 SP 등을 파악한다.

### 3. 인자 처리

- **`$ARGUMENTS`가 비어있는 경우**: 전체 프로젝트 현황을 요약하여 보여준다.
  - 프로젝트별: 현재 단계, 완료/진행중/남은 티켓 수, 남은 SP
  - 다음 착수할 작업 제안

- **`$ARGUMENTS`가 `update`인 경우**: **현재 대화 세션에서 파악한 정보를 바탕으로** 로컬 STATUS.md를 업데이트한다.
  - Notion을 다시 조회하지 않는다. 이번 세션에서 이미 확인한 티켓 상태, 논의된 내용, 작업 결과를 기반으로 갱신한다.
  1. 이번 세션에서 확인/변경된 티켓 상태를 정리
  2. STATUS.md의 티켓 테이블, 요약, 현재 단계를 세션 정보 기준으로 갱신
  3. "최종 업데이트" 날짜를 오늘로 변경
  4. 변경된 내용을 사용자에게 요약 보고

- **`$ARGUMENTS`가 프로젝트명인 경우** (예: `marketing-notice`): 해당 프로젝트의 STATUS.md와 관련 설계 문서를 읽고 상세 현황을 보여준다.

- **`$ARGUMENTS`가 `update <프로젝트명>`인 경우**: 특정 프로젝트의 STATUS.md만 세션 정보 기반으로 업데이트.

## 출력 형식

```
## 프로젝트 현황 (YYYY-MM-DD)

### [프로젝트명]
- 현재 단계: ...
- 티켓: 완료 N / 진행중 N / 남은 N (총 N SP)
- 다음 작업: ...
```

## 참고

- 프로젝트 메모리: `~/.claude/projects/-Users-herren/memory/MEMORY.md`
- Notion 백로그 DB: `collection://afbb2565-672a-44cd-85f4-45ba566e3613`

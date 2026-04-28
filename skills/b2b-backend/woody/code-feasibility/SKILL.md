---
name: b2b-backend-code-feasibility
description: 코드베이스를 탐색하여 기획 요구사항의 구현 가능성, 기존 코드 매핑, 영향도, 난이도를 분석하는 스킬. 코드체커(code-feasibility-checker) 에이전트가 사용한다.
---

# 코드 실현성 분석 (Code Feasibility)

## 워크플로우

### Step 0: 학습 기록 로드

1. `.claude/agents/learnings/codechecker_learnings.md` 파일 존재 확인 (Read 시도)
2. 존재하면:
   a. "활성 체크리스트" 섹션을 메모리에 로드
   b. 이후 분석 시 각 체크리스트 항목을 추가 점검 관점으로 활용
   c. 산출물의 "학습 패턴 체크 결과" 항목에 반영 여부 기록
3. 미존재 시: 건너뛰고 진행

### Step 1: 대상 모듈 식별

루나의 요구사항에서 키워드를 추출하여 관련 모듈을 식별한다.

**모듈 식별 기준:**
- 기능 키워드 → 패키지/클래스명 매칭
- 기존 유사 기능의 위치 참조
- CLAUDE.md의 모듈 구조표 참조

**반드시 확인:**
- 대상 모듈의 Spring Boot 버전 (2.7 vs 3.3)
- JPA 어노테이션 (javax vs jakarta)
- 빌드 설정 (build.gradle.kts)

**module_context.md 활용:**
- module_context.md가 제공된 경우 해당 파일의 모듈 컨텍스트를 사용
- 미제공 시 module-scanner 스킬의 워크플로우를 따라:
  1. {모듈}/build.gradle.kts Read
  2. Spring Boot 버전 추출
  3. javax/jakarta Grep count

### Step 2: 기능별 코드 매핑

각 기능에 대해 4레이어(Presentation → Application → Domain → Infrastructure) 순서로 탐색한다.

**탐색 방법:**
1. 관련 키워드로 Grep 검색 (클래스명, 메서드명, 엔티티명)
2. 매칭된 코드의 호출 체인 추적
3. 유사 기능 구현 패턴 식별

**각 기능에서 판단할 항목:**
- 매핑 결과: 신규 생성 / 기존 코드 수정 / 기존 코드 확장
- 수정 범위: 파일별 변경 유형과 영향도
- 난이도: 낮음(단순 CRUD) / 중간(비즈니스 로직 변경) / 높음(아키텍처 변경)
- 의존성: 선행 작업이 필요한 경우

### Step 3: 모듈 간 영향도 분석

단일 모듈을 넘어 의존하는 모듈들을 추적한다.

**핵심 enum/상수 발견 시 impact-tracer 활용:**
- impact-tracer 스킬의 워크플로우를 따라 영향도 전수 조사:
  1. 대상 클래스명으로 전체 프로젝트 Grep (head_limit: 0)
  2. 결과를 모듈별 그룹핑
  3. 총 영향 모듈 수와 파일 수 산출
  4. 검색 패턴을 산출물에 기록 (재현성)

**주의 포인트:**
- `gongbiz-common` / `gongbiz-crm-b2b-common` 변경 시 전체 영향
- 모듈 간 Spring Boot 버전 차이 (2.7 ↔ 3.3 호환성)
- 공유 엔티티/DTO 변경 시 다운스트림 영향

### Step 4: 기술 제약사항 도출

코드 분석 중 발견된 기술적 제약을 정리한다:
- 레거시 코드 제약 (MyBatis DAO, JSP 등)
- DB 스키마 제약 (FK, 인덱스, 컬럼 타입)
- 외부 시스템 연동 제약

### Step 5: 산출물 작성

`_workspace/02_codechecker_feasibility.md`에 에이전트 정의의 출력 형식대로 작성한다.

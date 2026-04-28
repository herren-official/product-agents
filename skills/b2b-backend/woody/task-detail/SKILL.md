---
name: b2b-backend-task-detail
description: TASK 골격 문서를 구현 명세서 수준으로 고도화하는 스킬. 디테일러(task-detailer) 에이전트가 사용한다. TASK 1개에 집중하여 코드베이스 심층 탐색 + 구현 코드 + 테스트 코드 + 검증까지 수행.
---

# TASK 고도화 (Task Detail)

## 워크플로우

### Step 1: 입력 확인

1. TASK 골격 문서 읽기 (`task/TASK-XX-키워드.md`)
2. 아키텍처 설계서 읽기 (`10_architect_design.md`) — TASK 관련 섹션 집중
3. 컨벤션 확인 (`.docs/conventions/developer-guide/`)
   - `02-package-structure.md` — 4계층 패키지 구조
   - `03-controller-dto.md` — Controller, DTO 패턴
   - `05-port-adapter.md` — Reader/Store Port + Adapter
   - `06-usecase-service.md` — UseCase vs Service 역할

### Step 2: 코드베이스 심층 탐색

> 이 단계가 핵심. 충분한 시간을 들여 기존 코드를 탐색한다.

1. TASK 골격의 "구현 범위"에 명시된 모듈의 기존 코드 구조 확인
   - 패키지 트리 (Glob)
   - 유사 기능 코드 (Grep + Read)
2. **패턴 답습 대상 식별:**
   - 같은 모듈의 기존 Controller/Service/UseCase/Repository 패턴
   - 어노테이션 사용법 (@ApplicationService, @Transactional 등)
   - DTO 변환 패턴 (Request → Command → Info → Response)
   - 예외 처리 패턴 (ErrorCode, Exception 클래스)
3. **기존 유사 테이블/엔티티 확인:**
   - DDL 관련 TASK면 기존 Liquibase changelog 패턴 확인
   - 기존 엔티티의 BaseEntity 상속, 어노테이션, 컬럼 네이밍 확인
4. **의존 TASK 산출물 확인:**
   - 선행 TASK가 있으면 해당 TASK 문서 읽기 (인터페이스, DTO 등 참조)

### Step 3: 구현 코드 작성

**신규 파일:** 전체 코드 작성 (복붙 가능 수준)
- 절대경로 명시
- import 포함
- 기존 패턴과 동일한 어노테이션, 네이밍
- 주석은 한국어, 평어

**기존 파일 수정:** diff 형태
- 어디에 추가하는지 위치 명시 (위아래 컨텍스트 포함)
- 추가(+) / 삭제(-) 명확 구분

**작성 기준:**
- 메서드 시그니처: 파라미터 타입 + 리턴 타입 명시
- 트랜잭션: `@Transactional` + propagation 명시
- 예외 처리: 어떤 예외 → 어떤 처리 (throw, catch, 로깅)
- DI: 생성자 주입 (기존 패턴 따름)

### Step 4: 테스트 코드 작성

**TDD Red/Green 기반:** 실제 테스트 코드 수준

1. **정상 케이스 (최소 2개):**
   ```kotlin
   @Test
   fun `설명`() {
       // given
       // when  
       // then (assert)
   }
   ```

2. **엣지 케이스 (최소 2개):**
   - 경계값 (0, MAX, NULL)
   - 동시성 (낙관적 락 충돌)
   - 상태 전이 오류 (잘못된 상태에서 전이 시도)
   - 중복 처리 (멱등성)

3. **유저 시나리오 (최소 1개):**
   - 원장님 관점 E2E (접수 → 차감 → 조립 → 발송 → 결과)

**테스트 프레임워크:** 기존 모듈 패턴 따름
- Kotlin 모듈: MockK + JUnit5
- Java 모듈: Mockito + JUnit5
- 통합 테스트: TestContainers (필요 시)

### Step 5: 설계서 교차 검증

1. 작성한 코드가 설계서(10_architect_design.md)의 해당 섹션과 일치하는지 확인:
   - DB 컬럼명/타입 일치
   - 상태 전이 흐름 일치
   - API 엔드포인트 일치
   - 비즈니스 정책 (차감, 수신거부, 야간 제한 등) 반영 여부
2. 불일치 발견 시 문서에 `> [!WARNING]` 블록으로 명시
3. 컨벤션 위반 자가 점검:
   - Domain에 Spring 어노테이션 없는지
   - DTO가 올바른 계층에 있는지
   - Reader/Store Port가 Domain에 있는지

### Step 6: DB 네이밍 자가 점검

DDL/엔티티 관련 TASK인 경우:
- [ ] 등록일시: `regdate` (created_at X)
- [ ] 수정일시: `moddate` (updated_at X)
- [ ] 일시 필드: `_datetime` 접미사 (_at X)
- [ ] 매장번호: `shopno` (shop_no X)
- [ ] 고객번호: `custno` (customer_no X)
- [ ] 테이블 접두사 통일 확인

### Step 7: 산출물 작성

TASK 골격 문서를 **덮어쓰기**하여 고도화된 구현 명세서로 업그레이드.
에이전트 정의(task-detailer.md)의 출력 형식을 따른다.

> Write 전 반드시 기존 파일을 Read한다.

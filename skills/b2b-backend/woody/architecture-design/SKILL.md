---
name: b2b-backend-architecture-design
description: 최종 스펙을 기반으로 아키텍처를 설계하는 스킬. 아키(architect) 에이전트가 사용한다.
---

# 아키텍처 설계 (Architecture Design)

## 워크플로우

### Step 1: 입력 자료 통합

1. `05_builder_final_spec.md` 전체 읽기
2. `02_codechecker_feasibility.md`에서 유사 구현 참조 목록 추출
3. `module_context.md`에서 대상 모듈 기술 스택 확인

### Step 2: 유사 구현 패턴 + 기존 DB 구조 분석

1. 코드체커가 식별한 유사 구현 참조를 실제로 Read
2. 패키지 구조, 클래스 네이밍, DI 패턴, 에러 처리 패턴을 추출
3. **기존 유사 DB 테이블 구조 직접 확인** (엔티티 코드 Read)
   - 신규 테이블 설계 시 기존 테이블(alimtalk_history, smshist 등)의 컬럼/타입/네이밍 참조
   - 기존 테이블과 통합 가능성 검토
4. 각 기능에 적용할 패턴을 결정하고 근거를 기록

### Step 2.5: 외부 API 스펙 직접 확인

1. 올빼미(researcher) 산출물이 있으면 읽기
2. **원본 API 문서도 직접 확인** (`ai/claude/docs/` 하위 또는 외부 문서)
   - 요청/응답 필드 전체 목록
   - 채널별 타입/옵션 (msgType, sendType 등)
   - fallback, 이미지 업로드 등 부가 기능
   - Rate Limit, 크기 제한 등 제약사항
3. 올빼미 산출물과 원본 문서의 불일치 발견 시 원본 기준으로 설계

### Step 3: 레이어별 설계

각 기능에 대해 4-레이어 설계:

**Presentation**: Controller, Request/Response DTO
- 기존 API 네이밍 컨벤션 확인 (Grep: `@RequestMapping`, `@GetMapping`)
- DTO는 기존 패턴 (record vs class vs data class) 확인

**Application**: UseCase/Service
- 기존 트랜잭션 패턴 확인
- 이벤트 발행 패턴 확인 (SQS, ApplicationEvent)

**Domain**: Entity, Repository, Policy/Specification
- JPA 어노테이션: module_context.md 기준 (javax/jakarta)
- 기존 엔티티의 상속 구조 확인 (BaseEntity 등)

**Infrastructure**: Adapter, Client, Configuration
- 외부 연동 클라이언트 패턴 (RestTemplate/WebClient/Feign/@HttpExchange)

### Step 4: DB 마이그레이션 설계

1. 신규 테이블: ERD 수준 설계 (컬럼, 타입, 제약, 인덱스)
2. 기존 테이블 변경: ALTER 문 개요
3. 마이그레이션 순서: FK 의존 관계 고려
4. Liquibase changeset 구조 제안 (해당 모듈이 Liquibase 사용 시)

### Step 5: 의존성 그래프 작성

기능 간 의존 관계를 파악:
1. 공유 엔티티/DTO를 사용하는 기능 간 연결
2. 공통 인터페이스를 구현하는 기능 간 연결
3. 독립적으로 실행 가능한 기능 그룹 식별

### Step 6: 컨벤션 검증

1. `.docs/conventions/developer-guide/` 하위 문서를 읽어 4계층 아키텍처 규칙 확인
2. 설계한 패키지 구조가 컨벤션과 일치하는지 검증:
   - Presentation → Application → Domain → Infrastructure 단방향 의존
   - Domain: 순수 모델 + Port(Reader/Store). Spring 어노테이션 금지
   - UseCase(`@ApplicationService`): Service 조합
   - Service(`@Service`): 단일 도메인 CRUD, 메서드별 `@Transactional`
   - DTO 3계층: Request/Response → Command/Info → QueryResult
3. 위반 사항 발견 시 Step 3으로 돌아가 수정

### Step 7: 산출물 작성

**산출물 경로:** `_workspace/{번호}_architect_design.md` (기본: `10_architect_design.md`)

**필수 포함 섹션:**
1. 개요 (배경, 목적, 전환 전략)
2. 시스템 아키텍처 (전체 플로우 차트 Mermaid, 모듈 구성표, 모듈별 책임)
3. 모듈별 패키지 구조 (컨벤션 기준 4계층)
4. DB 설계 (DDL + 컬럼 설명 + 상태 머신)
5. SQS 설계 (큐 목록 + 메시지 DTO + DLQ)
6. API 명세 (엔드포인트 목록)
7. 핵심 비즈니스 로직 (차감, 변수 치환, 멱등성 등)
8. 외부 연동 (벤더 스펙)
9. 인프라 (ECS, 네트워크, Liquibase 소유 모듈)
10. 확정 정책 + 잔여 리스크
11. 마일스톤 + 일정 (요약표 + Gantt)

**DB 네이밍 체크리스트 (산출물 작성 후 반드시 검증):**
- [ ] 등록일시: `regdate` (created_at X)
- [ ] 수정일시: `moddate` (updated_at X)
- [ ] 일시 필드: `_datetime` 접미사 (scheduled_datetime, sent_datetime 등. _at X)
- [ ] 매장번호: `shopno` (shop_no X)
- [ ] 고객번호: `custno` (customer_no X)
- [ ] 기존 DB 컬럼명과 일치하는지 확인 (기존 테이블의 엔티티 코드 Read)
- [ ] 상태 enum: 기존 프로젝트의 enum 확장 우선 (신규 생성보다)
- [ ] 테이블 접두사 통일 확인 (도메인별 notification_, booking_ 등)

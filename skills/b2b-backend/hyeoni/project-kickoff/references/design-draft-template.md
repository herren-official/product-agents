# {epic-project-name} 설계 문서 초안

> 📌 **초안 상태**
> `/project-kickoff`가 노션 정책/피그마/DB/코드베이스/AWS를 분석해 자동 생성한 **설계 문서 초안**이다.
> 구현 세부(파일 경로·클래스명·메서드 시그니처 등)는 PR 시점에 작성. 본 문서는 **"무엇을 만들고, 왜 그렇게 결정했는가"**에 집중한다.
>
> 각 섹션에는 다음 라벨이 달려 있다:
> - **[자동]** — 수집된 1차 정보에서 바로 추출 가능. 초안이 이미 채워져 있음.
> - **[자동·검증 필요]** — 자동 추출했지만 사실 여부 확인 필요. 원문과 대조 후 수정.
> - **[수동 검토 필요]** — 엔지니어가 사고·판단·합의로 채워야 할 부분. 초안은 빈 슬롯 또는 추론 제안.
>
> 최종 문서는 이 초안을 엔지니어가 이어받아 다듬은 결과다. 초안 상태에서 그대로 리뷰에 제출하지 말 것.

---

## 1. 개요

### 1.1 목표 **[자동·검증 필요]**
- {노션 정책에서 추출한 목표 bullet}
- {KPI·성공 지표가 있으면 인용}
- 기능불만/리스크 배경: {문제 원인 요약}

### 1.2 관련 문서 **[자동]**

| 문서 | 역할 | URL |
|---|---|---|
| {제목} | {역할 — 기획·요구사항·데이터 모델·회의록 등} | {URL} |

### 1.3 대상 모듈 / 버전 **[자동]**
- **주 모듈**: {예: `gongbiz-crm-b2b-backend` (Spring Boot 2.7.10, WAR)}
- **연관 모듈**: {예: `gongbiz-crm-b2b-admin` — 일부 Legacy Mapper 수정}
- **패키지**: {예: `v2.*` 신규 / `com.herren.gongbiz.*` 레거시}
- **JPA**: {`javax.persistence.*` | `jakarta.persistence.*`}
- **언어**: {Kotlin | Java — 신규 코드 기준}

> 모듈별 Spring Boot 버전 매핑은 `CLAUDE.md`의 "모듈별 Spring Boot 버전" 섹션 참조.

### 1.4 Phase별 작업 범위 **[수동 검토 필요]**

> 초안에는 **정책/피그마에서 추정한 분할**이 들어 있다. 실제 Phase 분할은 배포 일정/롤아웃 전략에 따라 엔지니어가 결정.

| Phase | 시점 | 작업 범위 (요약) |
|---|---|---|
| **Phase 1** | 본 PR | {스키마 + 신규 API + 구버전 호환 로직 + 마이그레이션} |
| Phase 2 | {다음 배포 후, 별도 PR} | {구버전 호환 로직 제거, 정리 배치} |
| Phase 3 | {선택, 장기} | {deprecated 컬럼 drop, 정책 정리} |

#### Phase 1 작업 상세 **[수동 검토 필요]**
1. {작업 1 — 예: 테이블 생성 + Liquibase changeset}
2. {작업 2 — 예: JPA Entity + Reader/Store Port + Adapter}
3. {작업 3}
...

#### Phase 2 작업 상세 **[수동 검토 필요]**
1. {작업 1 — 예: 구버전 호환 분기 제거}
2. {작업 2}

---

## 2. 전체 흐름 (AS-IS → TO-BE)

### 2.1 AS-IS **[자동·검증 필요]**

```
{자동 추출된 현재 구조. 관련 테이블/엔트리포인트/호출 순서를 도식으로 표현}
```

**현재 구조의 문제점 [자동·검증 필요]**
- {문제 1 — 노션에서 인용}
- {문제 2}

### 2.2 TO-BE 시퀀스 **[수동 검토 필요]**

> Mermaid 시퀀스 다이어그램을 채운다. 아래는 스켈레톤. 엔드포인트/메시지 흐름은 5절 API 설계가 확정된 후 작성.

```mermaid
sequenceDiagram
    participant C as Client
    participant API as {Controller}
    participant SVC as {Service/Facade}
    participant DB as DB
    participant EXT as {External — S3/Kafka/Lambda}

    Note over C,DB: {시나리오 1 — 예: 등록}
    C->>API: {HTTP Method Path}
    API->>SVC: {usecase 호출}
    SVC->>DB: {INSERT/UPDATE}
    SVC->>EXT: {외부 호출, 있으면}
    SVC-->>C: {응답}

    Note over C,DB: {시나리오 2 — 예: 수정}
    C->>API: {HTTP Method Path}
    ...
```

### 2.3 읽기 경로 **[수동 검토 필요]**

```plain text
{조회 경로 A}        ┐
{조회 경로 B}        ├─→ {타겟 테이블/Service}
{조회 경로 C}        ┘
```

- {경로 설명 — 어떤 Controller/Mapper에서 어디로 흐르는지}

---

## 3. 구성 범위

### 3.1 신규 구성 요소 **[수동 검토 필요]**

| 계층 | 구성 요소 | 역할 |
|---|---|---|
| Liquibase | DDL changeset | 테이블 생성 + master changelog 등록 |
| Domain | JPA Entity | {도메인 상수 포함} |
| Domain | Reader Port | 조회 인터페이스 |
| Domain | Store Port | 저장/삭제 인터페이스 |
| Infrastructure | Spring Data JPA Repository | 파생 쿼리 |
| Infrastructure | ReaderAdapter / StoreAdapter | Port 구현체 |
| Application | {Service/Facade} | {Application Service 책임} |
| Application | {Event Listener} | {필요 시 — 비동기 처리, 예: S3 삭제} |

### 3.2 기존 코드 수정 범위 **[자동·검증 필요]**

> `codebase-map.md`에서 감지된 영향 지점을 나열한다. 각 항목은 파일:라인 인용 필수.

| 영역 | 파일/위치 | 변경 내용 | Phase |
|---|---|---|---|
| {Legacy Mapper} | `{path}:{line}` | {서브쿼리 교체 등} | 1 |
| {V2 Service} | `{path}:{line}` | {Reader 교체} | 1 |
| {Request DTO} | `{path}:{line}` | {필드 추가} | 1 |
| {Facade} | `{path}:{line}` | {분기 로직} | 1 |

---

## 4. 데이터 모델

### 4.1 테이블 DDL **[수동 검토 필요]**

> 초안에는 노션 정책에 DDL이 명시되어 있으면 그대로, 없으면 컬럼/타입/제약 **추정안**을 넣는다. 엔지니어가 확정.

```sql
CREATE TABLE {table_name} (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    {col_1}         {TYPE}          NOT NULL COMMENT '{설명}',
    {col_2}         {TYPE}          NULL     COMMENT '{설명}',
    regdate         DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY {uk_name} ({cols}),
    INDEX {idx_name} ({cols})
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='{테이블 설명}';
```

### 4.2 Liquibase 번호 부여 **[자동]**
- changeset 번호는 **머지 시점에 최신 번호 재확인 후 부여**. 선행 PR 머지에 따라 번호가 변동되므로 본 문서에 숫자를 고정하지 않는다.
- 대상 changelog 파일: {예: `db/changelog/sql/{NNN}.{table_name}.sql` — 기존 테이블 변경 시 기존 파일에 append}

### 4.3 마이그레이션 **[수동 검토 필요]**

#### 예상 건수 **[자동·검증 필요]**
> `gongbiz-db` 스킬로 조회한 실제 건수를 기입. 없으면 "조회 필요"로 남긴다.

| 구분 | 건수 |
|---|---|
| {원본 테이블 전체} | {값} |
| {이관 대상 (필터 적용)} | {값} |

#### 배치 분할 전략 **[수동 검토 필요]**
- 분할 기준: {예: saleno 기준 / id range 기준}
- 분할 이유: {예: 같은 엔티티가 쪼개지면 안 되는 관계}

#### 실행 방식 **[수동 검토 필요]**
- 옵션 A: Stored Procedure (MariaDB 클라이언트만으로 실행)
- 옵션 B: 배치 Job
- 옵션 C: 실시간 dual-write

> 선택 후 상세 스크립트 및 실행 시퀀스 추가.

#### 4.3.1 롤백 체크리스트 **[수동 검토 필요]**
- [ ] 마이그레이션 후 row count 일치 확인
- [ ] 코드 배포 실패 시 대응 절차
- [ ] 부분 실패(배치 중단) 시 재실행 전략 (idempotent 보장)
- [ ] 배포 후 응답 이상 발생 시 복구 경로

---

## 5. API 설계

### 5.1 엔드포인트 요지 **[수동 검토 필요]**

> 초안에는 피그마 화면과 유사 기능 경로에서 추정한 엔드포인트 목록이 들어간다.

| HTTP | 경로 | 역할 | 권한 |
|---|---|---|---|
| `POST` | `/api/v2/{...}` | {...} | {토큰 종류} |
| `PUT` | `/api/v2/{...}/{id}` | {...} | {토큰 종류} |
| `GET` | `/api/v2/{...}/{id}` | {...} | {토큰 종류} |

### 5.2 Request/Response 샘플 **[수동 검토 필요]**

#### POST {path}

```json
POST {path}
Authorization: Bearer {shop-token}

{
  "{field_1}": "{value}",
  "{field_2}": { ... }
}
```

**Response 201 Created** — {Location 헤더 등 특이사항}

#### PUT {path}

```json
{
  "{field}": "{value}"
}
```

**Response 204 No Content**

### 5.3 공통 규칙 **[자동]**
- 응답 래퍼: V2 공통 `CommonApiResponse<T>` (신규 API 모듈 기준) 또는 레거시 응답 포맷
- 권한 체크: `@ShopToken`으로 `shopNo` 주입, Service에서 소유권 검증. 다른 매장 접근 시 `FORBIDDEN`
- 입력 검증: `javax.validation.constraints` 활용 (레거시) / `jakarta.validation.constraints` (신규)
- 날짜 포맷: DateTime `yyyy-MM-dd'T'HH:mm:ss`, Date `yyyy-MM-dd`

---

## 6. 내부 정책 / 분기 매트릭스 **[수동 검토 필요]**

> API가 여러 경로로 분기되는 경우 (예: 신버전/구버전 앱, 일반/펫샵, 이미지 포함/미포함 등) 매트릭스로 명시.

| 경로 | 조건 A | 조건 B | 클라이언트 | 내부 동작 |
|---|---|---|---|---|
| `POST /...` | {yes} | {no} | {신버전} | {동작 설명} |
| `PUT /...` | {no} | {yes} | {구버전} | {동작 설명} |

---

## 7. 주요 설계 결정 **[수동 검토 필요]**

> 각 결정은 아래 형식을 따른다:
> - **결정**: 무엇을 선택했나
> - **근거**: 왜 그렇게 선택했나 (대안과 비교)
> - **트레이드오프**: 감수해야 하는 부분
> - **결론**: 한 줄 정리

### 7.1 {결정 제목}
- **결정**: {...}
- **근거**:
  - {근거 1}
  - {근거 2}
- **트레이드오프**:
  - {감수 사항 1}
- **결론** — {한 줄 결론}

### 7.2 트랜잭션 경계
- **결정**: {Facade `@Transactional` 단일 경계 / 분리}
- **근거**: {...}
- **결론** — {한 줄 결론}

### 7.3 외부 시스템 호출 처리 (S3/Kafka/Lambda)
- **결정**: {동기 / `@TransactionalEventListener(AFTER_COMMIT)` + `@Async` / SQS 경유 등}
- **근거**: {...}
- **결론** — {한 줄 결론}

### 7.4 마이그레이션 vs 코드 배포 순서
- **결정**: {마이그레이션 선행 / 코드 선행 / dual-write}
- **근거**: {...}
- **결론** — {한 줄 결론}

### 7.5 기존 API 호환성
- **결정**: {JSON 키 유지 / breaking change 허용 / 버전 추가}
- **근거**: {...}
- **결론** — {한 줄 결론}

### 7.6 동시성/락
- **결정**: {비관적 락 / 낙관적 락 / 분산 락 / 없음}
- **근거**: {...}
- **결론** — {한 줄 결론}

### 7.7 보안/권한 검증 지점
- **결정**: {토큰 검증 위치, 입력 URL 소유권 검증, PII 로깅 정책 등}
- **근거**: {...}
- **결론** — {한 줄 결론}

---

## 8. 영향 범위 (모듈/레이어 관점) **[자동·검증 필요]**

> 초안에는 `codebase-map.md` 기반 **모듈/레이어 스캔 결과**가 들어간다. 작업 단위 분할은 1.4 Phase별 작업 참조.

| 대상 | 영향 | 비고 | 적용 Phase |
|---|---|---|---|
| **{모듈명}** | {Controller 추가} | `{path}` | 1 |
| **{모듈명}** | {Service 수정} | `{path}:{line}` 근처 | 1 |
| **{모듈명}** | {Mapper 서브쿼리 교체} | `{path}` | 1 |
| **DB** | 마이그레이션 스크립트 | {건수}건 | 1 |
| **Infrastructure** | {신규 로그 그룹/알람} | `infra-map.md` 참조 | 1 |

---

## 9. 관측 및 운영

### 9.1 로그 그룹 **[자동]**
- {로그 그룹명} — {용도}

### 9.2 알람/모니터링 **[수동 검토 필요]**
- {에러 임계치 / 지연 임계치 / 장애 알림 채널}

### 9.3 배포 후 확인 절차 **[수동 검토 필요]**
- [ ] {확인 항목 1 — 예: 특정 엔드포인트 200 응답률}
- [ ] {확인 항목 2 — 예: 신규 테이블 INSERT 건수}
- [ ] {확인 항목 3 — 예: 기존 경로 회귀 없음}

> QA 플랜은 구현 브랜치 생성 후 `/api-test-plan {branch}`로 별도 생성.

---

## 10. 논의 필요 항목 **[자동·검증 필요]**

> 노션/Slack에서 미결정으로 표기된 항목 + 자동 분석 중 발견된 불확실성.

| # | 항목 | 차단 여부 | 결정 주체 | 상태 |
|---|---|---|---|---|
| 1 | {예: API 분리 vs 통합} | Blocker | PM + BE | 미결정 |
| 2 | {예: 마이그레이션 타이밍} | 비차단 | BE | 미결정 |

---

## 11. 다음 액션

- [ ] 본 초안에 포함된 **[수동 검토 필요]** 섹션을 엔지니어가 채우기
- [ ] `architect` 에이전트에 초안 검토 요청 — 예: `Task(subagent_type="oh-my-claudecode:architect", prompt=".claude/docs/{epic}/design-draft.md를 검토하고 설계 결정의 트레이드오프 분석이 충분한지, Phase 분할이 타당한지 평가하라.")`
- [ ] `critic` 에이전트에 누락/리스크 재검증 — 예: `Task(subagent_type="oh-my-claudecode:critic", prompt="이 설계 초안에서 놓친 엣지 케이스, 누락된 API, 비현실적인 Phase 분할이 있는지 지적하라.")`
- [ ] 10번 논의 필요 항목을 팀 회의 안건으로 등록
- [ ] DDL Liquibase changeset 작성 (4.2 규칙 따라 번호 확정)
- [ ] 일감산정서 작성 후 `/create-task`로 Notion 백로그 카드 생성

---

## 출처 **[자동]**

- 노션: {URLs}
- 피그마: {URL/파일}
- DB 스키마 조회: `db-schema.md`
- 코드베이스 분석: `codebase-map.md`
- 인프라 분석: `infra-map.md`
- Slack 의사결정: `slack-notes.md` (수집된 경우)

---
name: b2b-backend-review-perf
description: 성능 관점 집중 코드 리뷰 (N+1, 인덱스, 페이지네이션, 캐시)
argument-hint: [file-path]
user-invocable: true
allowed-tools: Read, Bash, Grep, Glob
---

성능 관점에서 코드를 집중 리뷰해라.

## 입력

$ARGUMENTS

- 인자가 파일 경로이면 해당 파일을 대상으로 한다.
- 인자가 없으면 현재 브랜치와 develop 브랜치를 비교(`git diff develop...HEAD`)하여 변경된 파일을 대상으로 한다. develop 브랜치가 없으면 main, master 순으로 시도한다.

## 절차

### Step 1: 변경 코드 읽기
- 변경된 파일과 diff를 읽는다.
- 변경된 파일이 import하거나 주입받는 Entity, Repository, 설정 파일(application.yml 등)을 함께 읽어 전체 데이터 흐름을 파악한다.
- Spring Boot 버전을 확인한다 (2.x → javax, 3.x → jakarta).

### Step 2: 성능 체크리스트

**JPA / 쿼리:**
- N+1 쿼리: `@ManyToOne(fetch = LAZY)` + 루프 내 연관 엔티티 접근 → fetch join 또는 `@EntityGraph` 필요
- N+1 쿼리: 컬렉션 연관관계(`@OneToMany`)를 DTO 변환 시 루프에서 접근 → `@BatchSize` 또는 fetch join
- 전체 조회: `findAll()` 또는 `SELECT *`로 전체 데이터 조회 → 페이지네이션 적용
- 불필요한 컬럼: Entity 전체를 조회하지만 일부 필드만 사용 → Projection 또는 DTO 직접 조회
- 카운트 쿼리: `count(*)` + `findAll()` 분리 실행 → `Page` 반환으로 통합
- LIKE 검색: `%keyword%` 패턴 → 풀 테이블 스캔 가능, 인덱스 활용 불가
- Fetch Join + 페이지네이션: 컬렉션(`@OneToMany`) fetch join에 `Pageable`을 사용하면 Hibernate가 전체 결과를 메모리에 로딩 후 애플리케이션 레벨에서 페이징 (HHH000104 경고, OOM 위험) → `@BatchSize`, `@EntityGraph`, 또는 2-query 방식(ID 먼저 페이징 → IN절로 fetch) 권장

**인덱스:**
- WHERE 절에 사용되는 컬럼에 인덱스가 있는지 (확인 불가하면 "인덱스 확인 필요"로 표시)
- 복합 조건의 경우 복합 인덱스 순서가 적절한지
- ORDER BY + LIMIT 패턴에 정렬 컬럼 인덱스가 있는지

**메모리 / 처리량:**
- 대량 데이터를 List로 한 번에 로드하는가? → Stream 또는 Cursor 기반 처리 권장
- 루프 내 DB 호출이 있는가? → 배치 조회(IN 절)로 변환
- 루프 내 외부 API 호출이 있는가? → 비동기 또는 배치 호출
- 대용량 파일을 메모리에 전체 로드하는가? → InputStream 스트리밍 처리

**캐시:**
- 동일 파라미터로 반복 호출되는 읽기 전용 메서드가 있는가? → `@Cacheable` 적용 가능
- 캐시가 적용되어 있다면 무효화(eviction) 전략이 있는가?
- 캐시 키가 고유하게 설계되어 있는가?

**커넥션 / 리소스:**
- DB 커넥션 풀 소진 위험: 장시간 트랜잭션 내 외부 호출
- 파일/스트림 리소스 누수: try-with-resources 또는 `use {}` 없이 자원 사용
- 스레드 풀 소진: 무제한 `CompletableFuture.supplyAsync()` 사용

### Step 3: 영향도 분류
- **CRITICAL**: 운영 장애 가능 (OOM, 커넥션 풀 소진, 무한 루프)
- **WARNING**: 트래픽 증가 시 성능 저하 (N+1, 전체 조회, 캐시 미적용)
- **INFO**: 최적화 기회 (불필요한 컬럼 조회, 인덱스 제안)

## 출력 형식

```markdown
## 성능 리뷰

### 변경 요약
- 변경 파일: [N]개
- 언어: [Java / Kotlin / 혼재]
- Spring Boot: [버전 또는 "확인 불가"]
- DB 관련 변경: [있음/없음]
- 외부 연동 변경: [있음/없음]

### 성능 점검 결과
| # | 심각도 | 카테고리 | 파일:라인 | 문제 | 예상 영향 | 개선안 |
|---|--------|----------|----------|------|----------|--------|
| 1 | WARNING | N+1 | OrderService.kt:35 | 루프 내 연관 엔티티 접근 | 주문 N건당 쿼리 N+1개 | fetch join 적용 |
| 2 | WARNING | 전체 조회 | UserRepo.kt:10 | findAll() 사용 | 사용자 증가 시 OOM | 페이지네이션 적용 |
| 3 | INFO | 캐시 | ConfigService.kt:20 | 반복 호출 읽기 전용 | DB 부하 | @Cacheable 적용 |

### 수정 코드 (CRITICAL / WARNING)
#### #1 N+1 쿼리
\`\`\`kotlin
// 수정 전
@Query("SELECT o FROM Order o WHERE o.status = :status")
fun findByStatus(status: OrderStatus): List<Order>
// + 루프에서 order.items 접근 시 추가 쿼리 발생

// 수정 후
@Query("SELECT o FROM Order o JOIN FETCH o.items WHERE o.status = :status")
fun findByStatusWithItems(status: OrderStatus): List<Order>
\`\`\`

### 요약
- CRITICAL: [N]개 / WARNING: [N]개 / INFO: [N]개
- 주요 병목: [N+1 쿼리 / 전체 조회 / 커넥션 소진 / 없음]

### 다음 단계
- 종합 리뷰가 필요하면 `/review`를 실행하세요.
- 보안 리뷰가 필요하면 `/review-security`를 실행하세요.
- 복잡도 개선이 필요하면 `/simplify`를 실행하세요.
- 대규모 변경의 영향 범위 분석이 필요하면 "심층 리뷰해줘"라고 요청하세요.
```

## 제약

- 프로덕션 코드를 직접 수정하지 않는다. 수정 코드를 출력으로 제시한다.
- 인덱스 존재 여부를 코드만으로 확인할 수 없으면 "인덱스 확인 필요"로 표시한다.
- 추측이 아닌 코드에서 확인 가능한 성능 문제만 지적한다.
- develop/main/master 브랜치를 모두 찾을 수 없으면 "기준 브랜치를 찾을 수 없습니다. 대상 파일을 직접 지정해 주세요."를 출력한다.

---
name: b2b-backend-review
description: 시니어 백엔드 관점 종합 코드 리뷰
argument-hint: [file-path]
user-invocable: true
allowed-tools: Read, Bash, Grep, Glob
---

시니어 백엔드 개발자 관점에서 코드를 리뷰해라.

## 입력

$ARGUMENTS

- 인자가 파일 경로이면 해당 파일을 대상으로 한다.
- 인자가 없으면 현재 브랜치와 develop 브랜치를 비교(`git diff develop...HEAD`)하여 변경된 파일을 대상으로 한다. develop 브랜치가 없으면 main, master 순으로 시도한다.

## 절차

### Step 1: 변경 범위 파악
- `git diff develop...HEAD --stat`으로 변경 파일 목록과 규모를 확인한다.
- `git diff develop...HEAD`로 전체 diff를 읽는다.
- 변경된 파일의 원본도 함께 읽어 변경 전후를 비교한다.
- Spring Boot 버전을 확인한다 (2.x → javax, 3.x → jakarta).

### Step 2: 계층별 리뷰
변경된 코드의 계층(Controller, Service, Repository, Domain, Config)을 식별하고, 각 계층에 맞는 관점으로 리뷰한다.

**Controller:**
- 입력 검증: `@Valid`, `@Validated`, 커스텀 Validator 적용 여부
- 응답 포맷 일관성 (기존 프로젝트 패턴과 동일한지)
- 예외 핸들링: `@ExceptionHandler` 또는 전역 핸들러 위임 여부
- API 하위 호환성: 기존 클라이언트에 영향 주는 변경이 있는지

**Service:**
- 트랜잭션 경계: `@Transactional`의 범위가 하나의 비즈니스 단위와 일치하는지. `REQUIRES_NEW` 사용 시 외부 트랜잭션 롤백과 데이터 불일치 가능성을 확인한다
- 트랜잭션 내 외부 호출(HTTP, 메시징)이 있는지 (있으면 트랜잭션 밖으로 분리 권장)
- 비즈니스 예외와 시스템 예외가 분리되어 있는지
- 동시성: `@Version` 없이 read-modify-write 패턴이 있는지
- 멱등성: 재시도 시 부작용이 중복되지 않는지
- 조회 전용 메서드에 `@Transactional(readOnly = true)`가 적용되어 있는지

**Repository:**
- N+1 쿼리: `@ManyToOne(fetch = LAZY)` + 루프 내 접근, fetch join 미사용
- 인덱스 활용: WHERE 조건에 인덱스가 걸려있는지 (확인 불가하면 비고로 표시)
- 페이징 미적용: 전체 데이터를 `findAll()`로 조회하는지
- Native Query / JPQL 문법 오류 여부

**Domain:**
- Entity 동등성: `equals()`/`hashCode()` 구현이 올바른지 (ID 기반 vs 비즈니스 키 기반)
- Setter 노출: 무분별한 setter 대신 의미 있는 비즈니스 메서드를 사용하는지
- 불변 필드: 변경되면 안 되는 필드에 setter가 열려있지 않은지
- Entity-Schema 정합성: Entity가 변경/신규 작성 대상이면 마이그레이션 스크립트의 제약 조건과 Entity 어노테이션을 대조한다. NOT NULL/UNIQUE/FK nullable 불일치는 CRITICAL, VARCHAR 길이/INDEX 누락은 WARNING. 스크립트 미발견 시 비고 표시.

**Config / Infrastructure:**
- 민감정보(비밀번호, API 키)가 하드코딩되어 있지 않은지
- 환경별 설정 분리가 되어 있는지

### Step 3: 공통 체크리스트
- [ ] 비즈니스 흐름은 INFO, 예외는 ERROR, 디버깅용은 DEBUG로 설정되어 있는가
- [ ] 새 의존성이 추가되었으면 사유가 명확한가
- [ ] DB 스키마 변경이 필요한데 마이그레이션이 누락되지 않았는가
- [ ] Entity가 변경되었으면 마이그레이션 스크립트의 제약 조건(NOT NULL, UNIQUE, INDEX, 길이, FK)과 일치하는가
- [ ] 하위 호환성이 깨지는 변경이 있는가 (API 스펙, DB 스키마, 메시지 포맷)
- [ ] javax/jakarta 네임스페이스가 혼용되어 있지 않은가 (Boot 2.x→javax, 3.x→jakarta)

### Step 4: 심각도 분류 및 수정 코드 작성
모든 지적 사항에 심각도를 부여한다:
- **CRITICAL**: 운영 장애, 데이터 손실, 보안 취약점 → 반드시 수정 코드 포함
- **WARNING**: 성능 저하, 유지보수 비용 증가, 잠재적 버그 → 수정 권장, 코드 포함
- **INFO**: 컨벤션, 가독성, 네이밍 → 제안만

## 출력 형식

```markdown
## 코드 리뷰

### 변경 요약
- 변경 파일: [N]개
- 영향 계층: [Controller / Service / Repository / ...]
- Spring Boot: [버전]
- 언어: [Java / Kotlin]

### 리뷰 결과
| # | 심각도 | 파일:라인 | 문제 | 개선안 |
|---|--------|----------|------|--------|
| 1 | CRITICAL | OrderService.kt:45 | 트랜잭션 내 HTTP 호출 | 이벤트 기반으로 분리 |
| 2 | WARNING | OrderRepository.kt:12 | N+1 쿼리 가능성 | fetch join 적용 |
| 3 | INFO | OrderController.kt:20 | 메서드명 불명확 | processOrder → createOrder |

### 수정 코드 (CRITICAL / WARNING)
#### #1 트랜잭션 내 HTTP 호출
\`\`\`kotlin
// 수정 전
@Transactional
fun createOrder(request: CreateOrderRequest): OrderResponse {
    val order = orderRepository.save(Order.from(request))
    notificationClient.sendNotification(order)  // HTTP 호출
    return OrderResponse.from(order)
}

// 수정 후
@Transactional
fun createOrder(request: CreateOrderRequest): OrderResponse {
    val order = orderRepository.save(Order.from(request))
    eventPublisher.publishEvent(OrderCreatedEvent(order.id))
    return OrderResponse.from(order)
}

// 이벤트 리스너 (반드시 AFTER_COMMIT으로 처리)
@TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
fun handleOrderCreated(event: OrderCreatedEvent) {
    notificationClient.sendNotification(event.orderId)
}
\`\`\`

### 하위 호환성 영향
[Breaking change가 있으면 기술, 없으면 "없음"]

### 총평
- CRITICAL: [N]개 / WARNING: [N]개 / INFO: [N]개
- 전체 판정: [승인 / 수정 후 승인 / 재작성 권장]

### 다음 단계
- 보안 집중 리뷰가 필요하면 `/review-security`를 실행하세요.
- 성능 집중 리뷰가 필요하면 `/review-perf`를 실행하세요.
- 복잡도 개선이 필요하면 `/simplify`를 실행하세요.
- 대규모 변경의 영향 범위 분석이 필요하면 "심층 리뷰해줘"라고 요청하세요.
```

## 제약

- 변경하지 않은 코드에 대해서는 리뷰하지 않는다. 변경 diff에 집중한다.
- 프로덕션 코드를 직접 수정하지 않는다. 수정 코드를 출력으로 제시한다.
- develop/main/master 브랜치를 모두 찾을 수 없으면 "기준 브랜치를 찾을 수 없습니다. 대상 파일을 직접 지정해 주세요."를 출력한다.
- 변경 파일이 10개를 초과하면 계층별로 그룹화하여 출력한다.

# PR 리뷰 체크리스트

> 3단계 심각도별 통합 체크리스트 (fineadple-server)

## 개요

코드 리뷰 패턴 분석을 기반으로 한 체크리스트.
PR 올리기 전 스스로 점검하여 리뷰 피드백을 줄일 수 있습니다.

---

## Level 1: Critical (반드시 확인)

> 운영 장애로 이어질 수 있는 치명적 이슈

### 1.1 DDL/마이그레이션

- [ ] **롤백 changeset 존재**: 모든 마이그레이션에 rollback 정의
- [ ] **default/nullable 명시**: 컬럼 추가 시 기본값 또는 nullable 설정
- [ ] **대형 테이블 ALTER 검증**: 운영 데이터가 많은 테이블은 ALTER 시간 고려
- [ ] **유니크 제약 추가 시 중복 데이터 확인**: 기존 중복 데이터로 인한 마이그레이션 실패 방지

### 1.2 NPE (NullPointerException) 위험

- [ ] **nullable 필드 처리**: nullable 필드 접근 전 null 체크
- [ ] **Java<->Kotlin 호환성**: Java 코드에서 Kotlin nullable 타입 사용 시 `@Nullable` 어노테이션 확인
- [ ] **Optional 처리**: `orElse(null)` 대신 `orElseThrow()` 사용 권장
- [ ] **List.of() 주의**: `List.of()`는 null 요소 허용 안 함 (NPE 발생)
- [ ] **contains(null) 검증**: null 체크 후 contains 호출

**예시:**
```kotlin
// Bad: NPE 위험
if (state in listOf(OrderState.PENDING, null)) { ... }

// Good: 안전한 처리
val validStates = listOf(OrderState.PENDING, OrderState.COMPLETED)
if (state != null && state in validStates) { ... }
```

### 1.3 트랜잭션 경계

- [ ] **@Transactional 위치 검증**: Facade에서 여러 서비스 호출 시 트랜잭션 필요한지 확인
- [ ] **readOnly 설정**: 조회 전용 메서드는 `@Transactional(readOnly = true)`
- [ ] **부분 실패 시 롤백**: 여러 작업 중 일부 실패 시 전체 롤백 필요한지 확인
- [ ] **이벤트 전파 타이밍**: 트랜잭션 커밋 후 이벤트 발행되는지 확인
- [ ] **Race Condition 방지**: 동시 요청 가능한 API는 Pessimistic Lock 고려

### 1.4 PII (개인정보) 로깅

- [ ] **개인정보 마스킹**: 로그에 이름, 전화번호, 계좌번호 등 노출 금지
- [ ] **민감 데이터 로깅 제거**: 비밀번호, 토큰 등 로그 출력 금지
- [ ] **예외 스택에 개인정보 포함 여부**: Exception 메시지에 개인정보 포함 시 마스킹

### 1.5 외부 API 연동 안전성

- [ ] **Instagram API 호출 실패 처리**: 크롤링 실패 시 적절한 에러 핸들링
- [ ] **API 키/토큰 노출 방지**: 하드코딩된 API 키나 토큰이 없는지 확인
- [ ] **Rate Limiting 고려**: 외부 API 호출 빈도 제한 준수

---

## Level 2: Major (수정 권장)

> 코드 품질과 유지보수성에 영향

### 2.1 네이밍 컨벤션

- [ ] **camelCase 준수**: 파라미터/변수명
- [ ] **메서드명 명확성**: `get` vs `find` 구분 (단건/다건)
- [ ] **약어 최소화**: 의미 명확한 전체 이름 사용
- [ ] **boolean 네이밍**: `is`, `has`, `can` 접두사 사용

### 2.2 로깅

- [ ] **메서드명 prefix**: `[methodName]` 형식으로 로그 시작
- [ ] **주요 식별자 포함**: orderId, taskId 등 컨텍스트 정보
- [ ] **외부 API 실패 로깅**: Instagram API, 결제 API 등 외부 연동 실패 시 로그 필수
- [ ] **예외 상황 로깅**: catch 블록에 충분한 정보 로그
- [ ] **로그 레벨 적절**: DEBUG, INFO, WARN, ERROR 구분

**예시:**
```kotlin
log.info("[processOrder] 주문 처리 시작: orderId=$orderId")
try {
    orderService.process(orderId)
} catch (e: OrderException) {
    log.error("[processOrder] 주문 처리 실패: orderId=$orderId", e)
    throw e
}
```

### 2.3 아키텍처/레이어

- [ ] **모듈 의존성 방향**: common <- infrastructure <- 각 모듈 (순환 의존 금지)
- [ ] **Controller에 비즈니스 로직 금지**: Service/Facade로 위임
- [ ] **DTO 변환 위치**: Presentation 레이어에서 처리
- [ ] **infrastructure 모듈 변경 시**: 의존 모듈에 미치는 영향 확인

### 2.4 엣지 케이스

- [ ] **빈 리스트 처리**: 빈 리스트 반환 시 동작 확인
- [ ] **null 처리**: nullable 필드 접근 시 null 체크
- [ ] **시간 범위 검증**: start < end 확인
- [ ] **동시성**: 중복 요청 가능한 API는 동시성 제어
- [ ] **타임존**: 서버 시간 vs 사용자 시간 구분

### 2.5 테스트

- [ ] **변경 로직에 테스트**: 새 기능/버그 수정 시 테스트 추가
- [ ] **Given-When-Then**: 테스트 구조 명확히
- [ ] **@Disabled 확인**: 비활성화된 테스트 확인 및 활성화
- [ ] **엣지 케이스 테스트**: 경계값, null, 빈 리스트 등
- [ ] **Mock 사용**: 외부 API 호출은 MockWebServer/Mockk 사용

### 2.6 Kafka 메시징

- [ ] **메시지 직렬화/역직렬화**: 스키마 변경 시 하위 호환성
- [ ] **중복 소비 처리**: Consumer idempotency 보장
- [ ] **실패 메시지 처리**: DLQ(Dead Letter Queue) 또는 재시도 로직

---

## Level 3: Suggestion (선택적 개선)

> 코드 가독성과 유지보수성 향상

### 3.1 코드 스타일

- [ ] **중복 코드 추출**: 반복되는 로직 메서드로 추출
- [ ] **Early Return**: 중첩 if 대신 조기 반환
- [ ] **매직 넘버 상수화**: 숫자 리터럴 의미 있는 상수로 변경
- [ ] **불필요한 import 제거**: 사용하지 않는 import 정리

**예시:**
```kotlin
// Bad: 중첩 if
fun validate(order: Order) {
    if (order.isActive) {
        if (order.hasItems) {
            // 로직
        }
    }
}

// Good: Early Return
fun validate(order: Order) {
    if (!order.isActive) return
    if (!order.hasItems) return
    // 로직
}
```

### 3.2 인터페이스 분리

- [ ] **YAGNI 원칙**: 단일 구현만 있는 인터페이스 지양 (필요할 때 추출)
- [ ] **외부 서비스 추상화**: 외부 연동은 인터페이스로 분리 권장
- [ ] **검증 로직 분리**: 복잡한 검증은 별도 클래스로

---

## PR 작성 체크리스트

### PR 설명 필수 항목

- [ ] **개요**: 이 PR이 무엇을 하는지 한 문장 설명
- [ ] **변경 사항**: 파일/기능별 변경 내용
- [ ] **테스트**: 어떻게 테스트했는지
- [ ] **관련 이슈**: JIRA 티켓 번호 (IQLX-XXXXX)

---

## 빠른 체크 (5분 버전)

PR 올리기 직전 최소한 확인:

1. **컴파일 성공**
2. **테스트 통과**
3. **파라미터명 camelCase**
4. **null 체크**
5. **PR 설명 작성**
6. **로그에 PII 없음**

---

## 리뷰 예상 시간

| PR 복잡도 | 예상 시간 | 설명 |
|----------|----------|------|
| Trivial | ~5분 | 오타 수정, 설정 변경 |
| Simple | ~10분 | 작은 기능 추가 |
| Moderate | ~20분 | 중간 규모 기능 |
| Complex | ~45분 | 여러 파일 변경 |
| Very Complex | 1시간+ | 대규모 리팩토링 |

---

*마지막 업데이트: 2026-02-23*
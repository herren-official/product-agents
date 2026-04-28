# PR 리뷰 체크리스트

> 4단계 심각도별 통합 체크리스트

## 📋 개요

CodeRabbit + 사람 리뷰 패턴 분석을 통합한 체크리스트.
PR 올리기 전 스스로 점검하여 리뷰 피드백을 줄일 수 있습니다.

---

## Level 1: Critical (반드시 확인) 🔴

> 출처: 01-coderabbit-patterns.md
> 운영 장애로 이어질 수 있는 치명적 이슈

### 1.1 DDL/마이그레이션

- [ ] **롤백 changeset 존재**: 모든 마이그레이션에 rollback 정의
- [ ] **default/nullable 명시**: 컬럼 추가 시 기본값 또는 nullable 설정
- [ ] **대형 테이블 ALTER 검증**: 운영 데이터가 많은 테이블은 ALTER 시간 고려
- [ ] **스키마 필터**: precondition에 `TABLE_SCHEMA = DATABASE()` 포함
- [ ] **유니크 제약 추가 시 중복 데이터 확인**: 기존 중복 데이터로 인한 마이그레이션 실패 방지

**예시:**
```xml
<preConditions onFail="MARK_RAN">
    <and>
        <tableExists tableName="shop"/>
        <sqlCheck expectedResult="0">
            SELECT COUNT(*)
            FROM information_schema.TABLES
            WHERE TABLE_SCHEMA = DATABASE()
            AND TABLE_NAME = 'shop'
            AND (SELECT COUNT(*) FROM shop WHERE ...) > 0
        </sqlCheck>
    </and>
</preConditions>
```

### 1.2 NPE (NullPointerException) 위험

- [ ] **nullable 필드 처리**: nullable 필드 접근 전 null 체크
- [ ] **Java↔Kotlin 호환성**: Java 코드에서 Kotlin nullable 타입 사용 시 `@Nullable` 어노테이션 확인
- [ ] **Optional 처리**: `orElse(null)` 대신 `orElseThrow()` 사용 권장
- [ ] **List.of() 주의**: `List.of()`는 null 요소 허용 안 함 (NPE 발생)
- [ ] **contains(null) 검증**: null 체크 후 contains 호출

**예시:**
```kotlin
// ❌ NPE 위험
if (state in listOf(PaymentState.REGISTERED, null)) { ... }

// ✅ 안전한 처리
val validStates = listOf(PaymentState.REGISTERED, PaymentState.PAID)
if (state != null && state in validStates) { ... }
```

### 1.3 트랜잭션 경계

> 📖 컨벤션: [UseCase/Service TX 규칙](../../../../../conventions/developer-guide/06-usecase-service.md)

- [ ] **@Transactional 위치 검증**: Facade에서 여러 서비스 호출 시 트랜잭션 필요한지 확인
- [ ] **readOnly 설정**: 조회 전용 메서드는 `@Transactional(readOnly = true)`
- [ ] **부분 실패 시 롤백**: 여러 작업 중 일부 실패 시 전체 롤백 필요한지 확인
- [ ] **이벤트 전파 타이밍**: 트랜잭션 커밋 후 이벤트 발행되는지 확인
- [ ] **Race Condition 방지**: 동시 요청 가능한 API는 Pessimistic Lock 고려

**예시:**
```kotlin
@Transactional
fun updateShopAndSyncEmployees(command: UpdateCommand) {
    // Shop 업데이트
    shopService.update(command)

    // 직원 동기화 (같은 트랜잭션 내)
    employeeSyncService.syncAll(command.shopNo)

    // 실패 시 모두 롤백
}
```

### 1.4 PII (개인정보) 로깅

- [ ] **개인정보 마스킹**: 로그에 이름, 전화번호, 계좌번호 등 노출 금지
- [ ] **민감 데이터 로깅 제거**: 비밀번호, 토큰 등 로그 출력 금지
- [ ] **예외 스택에 개인정보 포함 여부**: Exception 메시지에 개인정보 포함 시 마스킹

**예시:**
```kotlin
// ❌ PII 노출
log.info("결제 실패: 예금주=${accountHolderName}, 계좌=${accountNumber}")

// ✅ 마스킹 처리
log.info("결제 실패: 예금주=${accountHolderName.mask()}, 계좌=${accountNumber.mask()}")
```

---

## Level 2: Major (수정 권장) 🟡

> 출처: 02-human-review-patterns.md
> 코드 품질과 유지보수성에 영향

### 2.1 네이밍 컨벤션

> 📖 컨벤션: [코드 컨벤션 가이드](../../../../../conventions/code-convention.md)

- [ ] **camelCase 준수**: 파라미터/변수명 (`ShopNo` → `shopNo`)
- [ ] **메서드명 명확성**: `get` vs `find` 구분 (단건/다건)
- [ ] **불필요한 접두사 제거**: `isInShopRestTime` → `isShopRestTime`
- [ ] **약어 최소화**: 의미 명확한 전체 이름 사용
- [ ] **boolean 네이밍**: `is`, `has`, `can` 접두사 사용

**예시:**
```kotlin
// ❌ 애매한 네이밍
fun isInShopRestTime(time: LocalTime): Boolean

// ✅ 명확한 네이밍
fun isShopRestTime(time: LocalTime): Boolean
```

### 2.2 로깅

- [ ] **메서드명 prefix**: `[methodName]` 형식으로 로그 시작
- [ ] **주요 식별자 포함**: shopNo, bookingNo 등 컨텍스트 정보
- [ ] **외부 API 실패 로깅**: 네이버, KIS 등 외부 연동 실패 시 로그 필수
- [ ] **예외 상황 로깅**: catch 블록에 충분한 정보 로그
- [ ] **로그 레벨 적절**: DEBUG, INFO, WARN, ERROR 구분

**예시:**
```kotlin
log.info("[syncNaverBooking] 네이버 예약 동기화 시작: shopNo=$shopNo")
try {
    naverClient.syncBooking(shopNo)
} catch (e: NaverApiException) {
    log.error("[syncNaverBooking] 네이버 API 호출 실패: shopNo=$shopNo", e)
    throw BookingSyncException("네이버 예약 동기화 실패", e)
}
```

### 2.3 아키텍처/레이어

> 📖 컨벤션: [패키지 구조](../../../../../conventions/developer-guide/02-package-structure.md) · [Port & Adapter](../../../../../conventions/developer-guide/05-port-adapter.md) · [UseCase/Service](../../../../../conventions/developer-guide/06-usecase-service.md) · [Controller/DTO](../../../../../conventions/developer-guide/03-controller-dto.md)

- [ ] **Reader 인터페이스 위치**: Domain 레이어에 위치
- [ ] **Reader 구현체 위치**: Infrastructure 레이어에 위치 (ReaderAdapter)
- [ ] **Store 인터페이스 위치**: Domain 레이어에 위치
- [ ] **Store 구현체 위치**: Infrastructure 레이어에 위치 (StoreAdapter)
- [ ] **Controller에 비즈니스 로직 금지**: UseCase/Service로 위임
- [ ] **레이어 간 의존성 방향**: Presentation → Application → Domain ← Infrastructure (DIP)
- [ ] **DTO 변환 위치**: Presentation 레이어에서 처리
- [ ] **UseCase 어노테이션**: 신규 모듈은 `@ApplicationService` 사용

**프로젝트 컨벤션 (4계층 + Port & Adapter):**
```
Domain Layer:
├── Reader Port (인터페이스)
├── Store Port (인터페이스)
└── Domain Service

Infrastructure Layer:
├── ReaderAdapter (Reader 구현체)
├── StoreAdapter (Store 구현체)
└── JpaRepository
```

### 2.4 도메인 지식베이스 동기화

- [ ] **Enum 변경 시 문서 동기화**: Enum 추가/수정/삭제 시 `.docs/domains/*.md` 해당 도메인 문서 업데이트
- [ ] **엔티티 필드 변경 시 문서 동기화**: 필드 추가/타입 변경 시 해당 도메인 문서 업데이트
- [ ] **상태 전이 변경 시 문서 동기화**: 상태 전이 규칙 변경 시 해당 도메인 문서의 상태 전이 다이어그램 업데이트
- [ ] **모듈 분포 확인**: Enum/엔티티가 여러 모듈에 복제되어 있으면 모든 모듈 동기화 (도메인 문서의 분포 테이블 참조)

**도메인 매핑:**

| 변경 파일 경로 패턴 | 도메인 문서 |
|-------------------|-----------|
| `**/booking/**` | `.docs/domains/booking.md` |
| `**/payment/**` | `.docs/domains/payment.md` |
| `**/settlement/**` | `.docs/domains/settlement.md` |
| `**/sale/**` | `.docs/domains/sale.md` |
| `**/shop/**` | `.docs/domains/shop.md` |
| `**/customer/**` | `.docs/domains/customer.md` |
| `**/cosmetic/**` | `.docs/domains/cosmeticproc.md` |
| `**/employee/**` | `.docs/domains/employee.md` |
| `**/notification/**`, `**/alimtalk/**` | `.docs/domains/notification.md` |
| `**/naver/**` | `.docs/domains/naver.md` |
| `**/ticket/**`, `**/membership/**`, `**/sharedpass/**` | `.docs/domains/ticket.md` |
| `**/businessday/**`, `**/shopholiday/**` | `.docs/domains/businessday.md` |

### 2.5 엣지 케이스 (기존 2.4)

- [ ] **빈 리스트 처리**: 빈 리스트 반환 시 동작 확인
- [ ] **null 처리**: nullable 필드 접근 시 null 체크
- [ ] **시간 범위 검증**: start < end 확인
- [ ] **24:00 케이스**: 자정 처리
- [ ] **동시성**: 중복 요청 가능한 API는 동시성 제어
- [ ] **타임존**: 서버 시간 vs 사용자 시간 구분

**예시:**
```kotlin
// 시간 범위 검증
require(startTime < endTime) { "시작 시간이 종료 시간보다 늦을 수 없습니다" }

// 빈 리스트 처리
if (restTimes.isEmpty()) {
    return emptyList()
}
```

### 2.6 테스트 (기존 2.5)

- [ ] **변경 로직에 테스트**: 새 기능/버그 수정 시 테스트 추가
- [ ] **Given-When-Then**: 테스트 구조 명확히
- [ ] **@Disabled 확인**: 비활성화된 테스트 확인 및 활성화
- [ ] **엣지 케이스 테스트**: 경계값, null, 빈 리스트 등
- [ ] **통합 테스트**: 외부 연동이 있는 경우 통합 테스트

---

## Level 3: Suggestion (선택적 개선) 🟢

> 출처: 02-human-review-patterns.md + 04-self-review-guide.md
> 코드 가독성과 유지보수성 향상

### 3.1 코드 스타일

> 📖 컨벤션: [코드 컨벤션 가이드](../../../../../conventions/code-convention.md) · [테스트/로깅/Kotlin](../../../../../conventions/developer-guide/09-test-logging-kotlin.md)

- [ ] **중복 코드 추출**: 반복되는 로직 메서드로 추출
- [ ] **Early Return**: 중첩 if 대신 조기 반환
- [ ] **매직 넘버 상수화**: 숫자 리터럴 의미 있는 상수로 변경
- [ ] **인덴테이션 정렬**: 일관된 들여쓰기
- [ ] **불필요한 import 제거**: 사용하지 않는 import 정리
- [ ] **줄 길이**: 120자 이내 권장

**예시:**
```kotlin
// ❌ 중첩 if
fun validate(shop: Shop) {
    if (shop.isActive) {
        if (shop.hasBusinessDay) {
            // 로직
        }
    }
}

// ✅ Early Return
fun validate(shop: Shop) {
    if (!shop.isActive) return
    if (!shop.hasBusinessDay) return
    // 로직
}
```

### 3.2 인터페이스 분리

- [ ] **YAGNI 원칙**: 단일 구현만 있는 인터페이스 지양 (필요할 때 추출)
- [ ] **외부 서비스 추상화**: 외부 연동은 인터페이스로 분리 권장
- [ ] **검증 로직 분리**: 복잡한 검증은 별도 클래스로

**예시:**
```kotlin
// ❌ 불필요한 인터페이스
interface ShopValidator {
    fun validate(shop: Shop)
}
class ShopValidatorImpl : ShopValidator { ... } // 단일 구현

// ✅ 필요 시에만 추출
class ShopValidator {
    fun validate(shop: Shop) { ... }
}

// ✅ 외부 서비스는 인터페이스 권장
interface PaymentVendorService {
    fun pay(request: PaymentRequest): PaymentResult
}
class KisPaymentService : PaymentVendorService { ... }
class NicePaymentService : PaymentVendorService { ... }
```

---

## Level 4: Domain-Specific (도메인별) 🔵

> 출처: 03-domain-knowledge.md
> 비즈니스 로직 관련 체크포인트 (동적 적용)

**이 섹션은 작업 도메인에 따라 다릅니다.**

상세 내용은 [domain-review-points.md](./domain-review-points.md)를 참조하세요.

### 주요 도메인

| 도메인 | 체크포인트 파일 |
|--------|-----------------|
| 예약/매출 | domain-review-points.md § 예약/매출 |
| 네이버 연동 | domain-review-points.md § 네이버 연동 |
| 영업 설정 | domain-review-points.md § 영업 설정 |
| 정산 | domain-review-points.md § 정산 |

**예시 (네이버 연동):**
- [ ] 네이버 API 호출 실패 시 로깅
- [ ] 결제 상태 검증 (REGISTERED, PAID)
- [ ] 동기화 실패 처리
- [ ] 웹훅 중복 처리 방지

**예시 (영업 설정):**
- [ ] 직원 영업시간 ⊆ 샵 영업시간
- [ ] 휴게시간 ⊆ 영업시간
- [ ] 휴게시간 중복 검증
- [ ] 시작 < 종료 검증

---

## 📝 PR 작성 체크리스트

### PR 설명 필수 항목

- [ ] **개요**: 이 PR이 무엇을 하는지 한 문장 설명
- [ ] **변경 사항**: 파일/기능별 변경 내용 (테이블 형식 권장)
- [ ] **테스트**: 어떻게 테스트했는지
- [ ] **관련 이슈**: JIRA 티켓 번호 (GBIZ-XXXXX)

**예시:**
```markdown
## 개요
직원 영업시간 설정 시 휴게시간 검증 기능 추가

## 변경 사항
| 파일 | 변경 내용 |
|------|----------|
| ShopRestTimeValidationService | 휴게시간 검증 로직 추가 |
| EmployeeBusinessDayFacade | 검증 서비스 주입 |

## 테스트
- 단위 테스트 16개 추가
- 통합 테스트 3개 추가

## 관련 이슈
- GBIZ-24015
```

---

## 🔄 리뷰 후 수정 응답

### 수정 완료 응답 형식

```
@리뷰어 [커밋해시] 수정하였습니다!
```

**예시:**
```
@herren-hyeoni [b7306ba] 수정하였습니다!
```

---

## 💡 빠른 체크 (5분 버전)

PR 올리기 직전 최소한 확인:

1. ✅ **컴파일 성공**
2. ✅ **테스트 통과**
3. ✅ **파라미터명 camelCase**
4. ✅ **null 체크**
5. ✅ **PR 설명 작성**
6. ✅ **로그에 PII 없음**

---

## 📊 리뷰 예상 시간

| PR 복잡도 | 예상 시간 | 설명 |
|----------|----------|------|
| 🟢 Trivial | ~5분 | 오타 수정, 설정 변경 |
| 🟡 Simple | ~10분 | 작은 기능 추가 |
| 🟠 Moderate | ~20분 | 중간 규모 기능 |
| 🔴 Complex | ~45분 | 여러 파일 변경 |
| ⚫ Very Complex | 1시간+ | 대규모 리팩토링 |

---

## 🎯 셀프 리뷰 가능성

### ✅ 셀프 리뷰로 잡을 수 있는 것
- Level 1: Critical (DDL, NPE, PII)
- Level 2: Major (네이밍, 로깅, 레이어)
- Level 3: Suggestion (코드 스타일)

### ⚠️ 사람 리뷰가 필요한 것
- Level 4: Domain-Specific (비즈니스 로직)
- 아키텍처 결정
- 성능 이슈
- 복잡한 비즈니스 규칙

---

## 📚 참고 문서

### 컨벤션 가이드

| 문서 | 설명 |
|------|------|
| [개발자 컨벤션 가이드](../../../../../conventions/developer-guide/README.md) | 실무 레퍼런스 (패키지 구조, Controller, DTO, Port&Adapter, UseCase/Service) |
| [코드 컨벤션 가이드](../../../../../conventions/code-convention.md) | 코드 작성 원칙, 리팩토링 가이드 |
| [커밋 컨벤션 가이드](../../../../../conventions/commit-convention.md) | 커밋 메시지 형식, 타입별 사용법 |
| [아키텍처 개선안](../../../../../conventions/architecture-improvement-proposal.md) | 아키텍처 방향성, 결정사항 |

### 리뷰 분석

| 문서 | 설명 |
|------|------|
| [domain-review-points.md](./domain-review-points.md) | 도메인별 상세 체크포인트 |
| [01-coderabbit-patterns.md](../../../.docs/crm/pr-review-analysis/01-coderabbit-patterns.md) | CodeRabbit 패턴 분석 |
| [02-human-review-patterns.md](../../../.docs/crm/pr-review-analysis/02-human-review-patterns.md) | 사람 리뷰 패턴 |
| [03-domain-knowledge.md](../../../.docs/crm/pr-review-analysis/03-domain-knowledge.md) | 도메인 지식 |
| [04-self-review-guide.md](../../../.docs/crm/pr-review-analysis/04-self-review-guide.md) | 셀프 리뷰 가이드 |

---

*마지막 업데이트: 2026-02-12*
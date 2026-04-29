# 도메인별 PR 리뷰 체크리스트

> instaget-server 도메인 특성에 따른 리뷰 포인트 정리

이 문서는 `analyze_pr.py`가 감지한 도메인에 해당하는 섹션만 동적으로 적용됩니다.

---

## 상품 (product)

**복잡도**: 높음
**관련 모듈**: `b2c_api`, `back_office_api`, `infrastructure`

### 리뷰 포인트
- [ ] ProductType 추가/변경 시 SNS 채널(Instagram, YouTube, Facebook, TikTok, Twitter, Kakao)과의 매핑 정합성
- [ ] 상품 가격 계산 로직 검증 (`getAmountByQuantity` — 수량별 할인율 적용)
- [ ] 일일 상품(`isDailyProductType`) vs 일반 상품 분기 로직 확인
- [ ] 포인트 충전 상품(`isPointCharge`) 특수 처리 — 쿠폰/포인트 사용 불가 제약
- [ ] ProductStatus 상태값 검증 (NOTSALE=-1, ADMIN_ORDER=0, SALEABLE=1)
- [ ] PriceOption, PriceLimitOption, ProductPriceSettingOption 설정 검증
- [ ] 상품 코드 중복 체크, 할인율 JSON 형식 검증
- [ ] 주문 수량 제한 (min/max/default) 범위 검증

### 주의사항
- 상품은 다차원 속성 (채널 × 타입 × 계정유형 × 일일여부)으로 구성됨
- 가격 변경 시 기존 주문/구매에 영향 없도록 주문 시점의 가격을 OrderItem에 스냅샷
- `ProductTaskAccountType` (KOREAN/GLOBAL)에 따라 작업 벤더가 달라짐
- infrastructure의 `ProductJpaEntity` 변경 시 모든 의존 모듈에 영향
- 정규표현식(`regex`) 필드는 주문 입력값 검증에 사용됨

---

## 구매/결제 (purchase)

**복잡도**: 높음
**관련 모듈**: `b2c_api`, `infrastructure`

### 리뷰 포인트
- [ ] 구매 상태 전이 규칙 준수
  - `ORDER_FORM(-99) → WAITING_PAYMENT(0) → PAID(1)`
  - 환불: `PAID → WAITING_REFUND(-1) → REFUNDED(-10) / MILEAGE_REFUND(-11)`
  - 부분 환불: `PARTIAL_MILEAGE_REFUND(-2) / PARTIAL_CASH_REFUND(-3)`
- [ ] 결제 수단별 플로우 구분 (CARD, NO_DEPOSIT_KRW, FULL_MILEAGE_PURCHASE, NAVER_PAY, KAKAO_PAY)
- [ ] NicePay 결제 승인 시 위변조 검증 (Sign Data, Signature)
- [ ] 결제 금액 = 주문 총액 일치 검증 (`IG0058` 오류 방지)
- [ ] 포인트 차감 시 잔액 충분성 검증 (`IG0022` 오류)
- [ ] 환불 시 포인트 복원 및 쿠폰 상태 원복 처리
- [ ] 무통장입금(Deposit) 상태 관리 (BEFORE_CHECK → CONFIRMED)
- [ ] 구매 승인 후 TaskHistory 자동 생성 로직 검증

### 주의사항
- `PurchaseCreateService`, `PurchaseApproveService`, `PurchaseAggregateService` 역할 구분 명확히
- NicePay 통신 실패 시 네트워크 취소 요청 처리 (`ReadTimeoutException`, `IOException`)
- 결제 승인은 `@Transactional` 내에서 원자적으로 처리해야 함
- 쿠폰 사용 결제 취소 시 쿠폰 재사용 가능 상태로 복원
- 한 결제에 쿠폰 2개 이상 사용 방지 (`IG0076`)
- 포인트 충전 상품은 쿠폰/포인트 결합 사용 불가 (`IG0095`)

---

## 주문 (order)

**복잡도**: 중간
**관련 모듈**: `b2c_api`, `infrastructure`

### 리뷰 포인트
- [ ] OrderItem 생성 시 필수 필드 검증 (quantity, target, targetKey, cost, amount)
- [ ] Target JSON 구조 검증 (InstagramInfo, YouTubeInfo 변환)
- [ ] 주문 금액 계산 정합성 (cost × quantity - discount = amount)
- [ ] 할인율(`discountRate`)이 DB 상품 할인율과 일치 (`IG0057`)
- [ ] TaskDelayMinutes 설정값 검증 (음수 불가)
- [ ] 포인트 충전 상품의 `chargePointAmount` 필드 처리

### 주의사항
- OrderItem의 Target 필드는 SNS 채널별로 다른 JSON 구조를 가짐
- `TargetKey`는 Instagram 사용자명, YouTube URL 등 작업 대상 식별자
- 주문 생성 시점의 가격을 스냅샷하여 나중 가격 변경과 무관하게 처리
- 관리자 대량 주문 시 판매 불가 상품 체크 (`IG0071`)

---

## 포인트 (point)

**복잡도**: 높음
**관련 모듈**: `b2c_api`, `back_office_api`, `infrastructure`

### 리뷰 포인트
- [ ] PointType 분류 정확성 (11개 타입)
  - 적립: REWARD_BY_PURCHASE(1), REWARD_BY_NO_DEPOSIT_PURCHASE(3), REWARD_BY_SIGN_UP(4), REWARD_BY_REVIEW(11), REWARD_BY_ADMIN(12), REWARD_BY_EVENT(14), REWARD_BY_POINT_CHARGE(16)
  - 차감: USE_BY_PURCHASE(2), EXPIRED(5), RECLAIM_BY_EVENT(15)
  - 환불: REFUND_BY_PURCHASE(6)
- [ ] FIFO 기반 포인트 차감 로직 검증 (만료일 빠른 포인트부터 차감)
- [ ] 포인트 잔액 정합성 (Member.point와 PointHistory 합계 일치)
- [ ] 관리자 포인트 지급/회수 시 AdminPointHistoryNote 감사 이력 기록
- [ ] 포인트 만료 배치 처리 시 정확한 만료일 검증
- [ ] 포인트 충전 상품 결제 시 REWARD_BY_POINT_CHARGE 타입으로 기록

### 주의사항
- 포인트는 결제 수단과 적립금 이중 역할 (사용 vs 적립 흐름 구분)
- 포인트 차감은 FIFO 방식 — 만료일이 가까운 것부터 차감
- 관리자 포인트 지급 시 음수 금액 검증 필수 (차감 시에만 음수 허용)
- PointHistory 생성 시 Balance 필드에 잔액 스냅샷 기록
- ExpirationDatetime 설정 누락 시 포인트 영구 보유 문제 발생 가능

---

## 작업 관리 (task)

**복잡도**: 높음
**관련 모듈**: `task_scheduler`, `task_client`, `b2c_api`, `back_office_api`, `infrastructure`

### 리뷰 포인트
- [ ] TaskHistory 상태 전이 규칙 (0:대기 → 1:진행 → 2:완료, -1:실패, -2:취소)
- [ ] TaskSchedule → TaskScheduleDetail 생성 로직 (수량 분배)
- [ ] Kafka 메시지 발행/소비 정합성 (채널별 토픽: Instagram, YouTube, Facebook, TikTok, Twitter, Kakao)
- [ ] 벤더 API 호출 실패 시 재시도/DLQ 처리
- [ ] 일일 작업 생성 시 23:00-24:00 KST 필터링 로직
- [ ] 작업 재처리(`reprocessTask`) 시 중복 실행 방지
- [ ] TaskFactoryFlag별 벤더 라우팅 정확성
- [ ] ShedLock으로 배치 중복 실행 방지 확인

### 주의사항
- Task 흐름: 구매 → TaskHistory 생성 → TaskSchedule 생성 → Kafka 발행 → TaskClient 소비 → 벤더 API 실행
- `TaskScheduleDetail`은 개별 작업 실행 단위 (수량 분할)
- 벤더 응답 실패 시 Sentry로 에러 추적
- 일일 상품은 매일 반복 실행되므로 StartDate/EndDate 범위 검증 필수
- task_scheduler의 배치 변경 시 task_client 소비 로직도 함께 확인
- 벤더 잔액 부족 시 Slack 알림 발송 로직 확인

---

## 크롤링 (crawling)

**복잡도**: 중간
**관련 모듈**: `instagram_crawler_api`, `infrastructure`, `daily_task_crawler`

### 리뷰 포인트
- [ ] Instagram Web API ↔ App API 폴백(fallback) 전환 로직 검증
- [ ] 크롤링 실패 시 적절한 에러 핸들링 (User Not Found, Private User, Invalid Shortcode 등)
- [ ] Rate Limiting 준수 (외부 API 호출 빈도 제한)
- [ ] 크롤링 결과 DTO 변환 정합성 (mapper 로직)
- [ ] YouTube RapidAPI 연동 시 API 키 노출 방지
- [ ] CrawlingResultHistory 이력 기록 정확성
- [ ] MockWebServer 기반 테스트 커버리지 (실제 API 호출 테스트 금지)

### 주의사항
- Instagram 크롤링은 Web API 우선, 실패 시 App API로 폴백
- 모든 외부 API 테스트는 MockWebServer로 모킹 (27개 테스트)
- Share Code → Shortcode 변환 로직 검증 필수
- Instagram PK(사용자 ID) 조회 실패 시 일일 작업 자동화에 영향
- Ktor HTTP 클라이언트 설정 변경 시 타임아웃/재시도 정책 확인

---

## 회원 (member)

**복잡도**: 중간
**관련 모듈**: `b2c_api`, `infrastructure`

### 리뷰 포인트
- [ ] JWT 토큰 생성/검증 로직 (현재 키 + 레거시 키 호환성)
- [ ] 회원 상태 전이 규칙 (REQUIRED_EMAIL_AUTH → NORMAL → STOP/DELETED/ADMINISTRATOR)
- [ ] 가입 유형별 처리 분기 (EMAIL, NAVER, FACEBOOK, KAKAO)
- [ ] Spring Security 권한 매핑 (ROLE_USER / ROLE_ADMIN)
- [ ] 비밀번호 재설정 토큰 만료 검증
- [ ] 소셜 로그인 회원의 비밀번호 재설정 차단 (`IG0037`, `IG0038`)

### 주의사항
- JWT Secret Key는 32자 HMAC-SHA256 + 레거시 27자 키 이중 지원
- Facebook OAuth는 2023-12-13부터 deprecated — 기존 회원만 지원
- 회원 삭제는 소프트 삭제 (`MemberStatus.DELETED`)
- 회원 포인트 잔액은 Member 엔티티에 캐시되어 있으므로 PointHistory와 정합성 유지 필수
- IP 기반 접근 제어 (`AdminAccessIp`) 변경 시 운영 환경 영향 확인

---

## 알림 (notification)

**복잡도**: 중간
**관련 모듈**: `notification`, `infrastructure`

### 리뷰 포인트
- [ ] 알림톡 템플릿 코드와 변수 일치 검증 (Biztalk API)
- [ ] 중복 발송 방지 로직 (`DuplicateSendAlimTalkChecker`)
- [ ] Biztalk 토큰 만료 시 자동 갱신 처리
- [ ] 알림 발송 이력(AlimTalkHistory) 기록 및 응답 코드 저장
- [ ] FriendTalk 프로모션 메시지 발송 시 수신 동의 확인
- [ ] 알림 발송 실패 시 로깅 (Sentry/Slack)

### 주의사항
- 알림톡 템플릿은 카카오 사전 승인 필요 — 미승인 템플릿 사용 시 발송 실패
- Biztalk 토큰은 만료 시간 체크 후 갱신 (배치 처리)
- 첨부파일(AlimTalkAttach) 생성 로직 검증
- 포인트 적립/차감, 구매 완료, 작업 상태 변경 시 알림 발송 트리거 확인

---

## 인스타터 주문 자동화 (instarter)

**복잡도**: 높음
**관련 모듈**: `instarter_order_automation`, `infrastructure`

### 리뷰 포인트
- [ ] Cafe24 API 주문 조회 시 시간 범위 검증 (30분 lookback)
- [ ] InstarterPurchase/InstarterOrderItem 생성 정합성
- [ ] 자동화 가능 여부 판단 로직 (자동화 상품 매핑 확인)
- [ ] Instagram PK 크롤링 실패 시 에러 처리 (일일 상품)
- [ ] Share Code → Shortcode 변환, @ 제거, URL 변환 등 타겟 정규화 로직
- [ ] 중복 TaskHistory 생성 방지 (이미 처리된 주문 체크)
- [ ] 수량 계산 로직 (단일 타겟 vs 복수 타겟)
- [ ] Cafe24 토큰 갱신 로직 검증

### 주의사항
- 주문 상태: PENDING → IN_PROGRESS → COMPLETED / ERROR
- 부분 자동화 허용 — 일부 아이템만 PENDING, 나머지 ERROR 가능
- 24시간 내 IN_PROGRESS 구매만 TaskHistory 생성 대상
- Instagram 사용자명에서 @ 제거, Twitter/TikTok ID → 전체 URL 변환 필수
- 패키지 상품(`isPackageProduct`)은 여러 상품 옵션을 포함하므로 수량 계산 주의

---

## 쿠폰 (coupon)

**복잡도**: 낮음
**관련 모듈**: `b2c_api`, `back_office_api`, `infrastructure`

### 리뷰 포인트
- [ ] 쿠폰 사용 가능 조건 검증 (최소 금액, 유효기간)
- [ ] 한 결제당 쿠폰 1개 제한 (`IG0076`)
- [ ] 쿠폰 할인 금액 계산 정확성 (`IG0075`)
- [ ] 결제 취소 시 쿠폰 상태 복원
- [ ] 포인트 충전 상품에 쿠폰 사용 불가 제약 (`IG0095`)

### 주의사항
- 상품 금액이 쿠폰 최소 사용 금액보다 낮으면 사용 불가 (`IG0074`)
- 이미 사용된 쿠폰 재사용 방지 (`IG0077`)
- MemberCoupon ↔ Coupon 관계 정합성 확인

---

## 리뷰 (review)

**복잡도**: 낮음
**관련 모듈**: `b2c_api`, `back_office_api`, `infrastructure`

### 리뷰 포인트
- [ ] 서비스당 리뷰 1회 제한 (`IG0049`)
- [ ] 리뷰 작성 시 포인트 적립 (REWARD_BY_REVIEW) 처리
- [ ] 리뷰 삭제 시 적립 포인트 회수 여부 확인
- [ ] S3 이미지 업로드 시 파일 형식/크기 검증 (`IG0047`, `IG0048`)

### 주의사항
- 리뷰는 TaskHistory(서비스 완료) 후에만 작성 가능
- 리뷰 포인트 적립은 PointHistory에 Review 참조로 기록

---

## 리필 (refill)

**복잡도**: 낮음
**관련 모듈**: `back_office_api`, `infrastructure`

### 리뷰 포인트
- [ ] 리필 대상 TaskHistory 상태 검증 (완료된 작업만 리필 가능)
- [ ] 리필 수량 계산 로직 (원래 수량 - 달성 수량)
- [ ] 리필 시 새 TaskSchedule 생성 로직

### 주의사항
- 리필은 작업 미달성 시 추가 실행하는 보충 작업
- 기존 TaskHistory와의 연관 관계 유지

---

## 벤더 (vendor)

**복잡도**: 중간
**관련 모듈**: `task_scheduler`, `task_client`, `back_office_api`, `infrastructure`

### 리뷰 포인트
- [ ] 벤더 API 연동 시 인증 정보(API Key/Token) 노출 방지
- [ ] 벤더 잔액 체크 배치 정확성 (`CheckVendorBalanceService`)
- [ ] 벤더 상태 체크 로직 (`CheckVendorStatusService`)
- [ ] 지연 벤더 감지 및 Slack 알림 (`CheckDelayedVendorService`)
- [ ] 벤더별 주문 실행 로직 분기 (TaskFactoryFlag)

### 주의사항
- 벤더 API 호출은 task_client에서 Kafka 메시지 소비 후 실행
- 벤더 잔액 부족 시 Slack ALERT 레벨 알림 발송
- 벤더 정보 변경 시 task_scheduler ↔ task_client 양쪽 영향 확인
- vendor-keys.yml에 벤더별 인증 정보 — 절대 커밋 금지

---

## 일일 작업 (dailyTask)

**복잡도**: 중간
**관련 모듈**: `daily_task_crawler`, `task_scheduler`, `infrastructure`

### 리뷰 포인트
- [ ] 일일 작업 생성 시간 필터링 (23:00-24:00 KST 생성분 제외)
- [ ] DailyTask → TaskSchedule 변환 로직 정확성
- [ ] 크롤링 필요 여부 판단 (`isProductToBeCrawledOnOrder`)
- [ ] 일일 노출 상품 특수 처리 (Web 크롤러 전용)
- [ ] StartDate/EndDate 범위 내에서만 작업 실행

### 주의사항
- 일일 상품은 매일 반복 실행되므로 중복 생성 방지 필수
- 크롤링 결과 기반 타겟 설정 — 크롤링 실패 시 작업 생성 불가
- daily_task_crawler 변경 시 task_scheduler의 `createDailyTask` 배치와 연동 확인

---

## 모니터링 (monitoring)

**복잡도**: 낮음
**관련 모듈**: `monitoring`, `infrastructure`

### 리뷰 포인트
- [ ] 메트릭 수집 배치 정확성
- [ ] 수집된 데이터의 시계열 저장 검증
- [ ] ShedLock 설정으로 배치 중복 실행 방지

### 주의사항
- 모니터링 데이터 수집 주기와 대상 확인
- Actuator 헬스체크 엔드포인트 접근 제한

---

## infrastructure 공통

**복잡도**: 높음
**관련 모듈**: 전체 (모든 모듈이 의존)

### 리뷰 포인트
- [ ] JPA 엔티티 변경 시 모든 의존 모듈에 미치는 영향 확인
- [ ] Liquibase 마이그레이션 추가 시 롤백 changeset 포함
- [ ] Ktor HTTP 클라이언트 설정 변경 시 타임아웃/재시도 정책 검증
- [ ] Kafka 토픽/프로듀서 설정 변경 시 컨슈머(task_client) 호환성 확인
- [ ] Slack API 알림 레벨 적절성 (INFO, WARNING, ALERT)
- [ ] Sentry 에러 추적 설정 정확성
- [ ] plain.jar 생성 방지 설정 유지 확인 (`archiveClassifier.set("")`)

### 주의사항
- infrastructure 변경 시 반드시 의존 모듈 재빌드: `./gradlew :infrastructure:build -x test`
- 엔티티 필드 추가/변경 시 Liquibase 마이그레이션과 동기화 필수
- 크롤러 API 인터페이스 변경 시 instagram_crawler_api, daily_task_crawler 영향
- Kafka DTO 스키마 변경 시 하위 호환성 유지 (task_scheduler ↔ task_client)

---

## 리뷰 자동화 가이드

### 도메인 감지 로직 (analyze_pr.py)

```python
# 변경된 파일 경로를 기반으로 도메인 자동 감지
DOMAIN_PATTERNS = {
    'product': ['product', 'ProductType', 'ProductSnsChannel', 'PriceOption'],
    'purchase': ['purchase', 'Purchase', 'nicepay', 'Nicepay', 'deposit', 'Deposit'],
    'order': ['order', 'Order', 'OrderItem'],
    'point': ['point', 'Point', 'PointHistory', 'PointType', 'mileage'],
    'task': ['task', 'Task', 'TaskHistory', 'TaskSchedule', 'kafka'],
    'crawling': ['crawler', 'crawling', 'Crawling', 'instagram', 'youtube'],
    'member': ['member', 'Member', 'jwt', 'Jwt', 'auth', 'Auth', 'security'],
    'notification': ['notification', 'alimtalk', 'friendtalk', 'biztalk'],
    'instarter': ['instarter', 'Instarter', 'cafe24', 'Cafe24'],
    'coupon': ['coupon', 'Coupon', 'MemberCoupon'],
    'review': ['review', 'Review'],
    'refill': ['refill', 'Refill'],
    'vendor': ['vendor', 'Vendor', 'VendorBalance'],
    'dailyTask': ['dailyTask', 'DailyTask', 'daily_task'],
    'monitoring': ['monitoring', 'collectApplicationStatus', 'metric'],
    'infrastructure': ['infrastructure', 'persistence', 'jpa']
}
```

### 리뷰 체크리스트 적용

1. PR 분석 스크립트가 변경된 파일 경로에서 도메인 키워드 감지
2. 감지된 도메인에 해당하는 섹션만 리뷰 코멘트에 포함
3. 복잡도가 '높음'인 도메인은 반드시 관련 도메인 전문가 리뷰 권장

### 복잡도별 리뷰 전략

| 복잡도 | 도메인 | 리뷰 전략 |
|--------|--------|-----------|
| **높음** | 상품, 구매/결제, 포인트, 작업 관리, 인스타터 주문 자동화, infrastructure | 도메인 전문가 리뷰 필수, 단위 테스트 필수 |
| **중간** | 주문, 크롤링, 회원, 알림, 벤더, 일일 작업 | 체크리스트 기반 셀프 리뷰 가능, 통합 테스트 권장 |
| **낮음** | 쿠폰, 리뷰, 리필, 모니터링 | 기본 검증만으로 충분, 단위 테스트 권장 |

### 모듈 의존성 그래프

```
common (기반 라이브러리)
    ↓
infrastructure (공유 인프라: 엔티티, 크롤러, Kafka, Slack)
    ↓
    ├─ b2c_api (B2C REST API — Java 17)
    ├─ back_office_api (관리자 API — Kotlin)
    ├─ task_scheduler (배치 스케줄러 — Kotlin)
    ├─ task_client (Kafka 컨슈머 워커 — Kotlin)
    ├─ instagram_crawler_api (크롤링 API — Kotlin)
    ├─ daily_task_crawler (일일 크롤링 배치 — Kotlin)
    ├─ instarter_order_automation (주문 자동화 — Kotlin)
    ├─ notification (알림 서비스 — Kotlin)
    └─ monitoring (모니터링 배치 — Kotlin)
```

### 크로스 모듈 변경 시 주의사항

| 변경 모듈 | 확인 필요 모듈 | 이유 |
|-----------|--------------|------|
| infrastructure (엔티티) | 전체 | 모든 모듈이 JPA 엔티티 의존 |
| infrastructure (Kafka) | task_scheduler, task_client | 프로듀서/컨슈머 스키마 일치 |
| infrastructure (크롤러) | instagram_crawler_api, daily_task_crawler | 크롤러 인터페이스 의존 |
| b2c_api (상품/구매) | back_office_api, task_scheduler | 관리자 상품 관리, 작업 생성 |
| task_scheduler (배치) | task_client | 메시지 포맷, 토픽 일치 |

---

*마지막 업데이트: 2026-02-24*
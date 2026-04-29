---
name: fineadple-backend-refactoring-assistant
description: fineadple-server 프로젝트 코드를 팀 컨벤션에 맞춰 분석하고, 멀티 모듈 영향도 분석을 통해 체계적으로 리팩토링합니다. "refactor", "apply conventions", "check code quality", "improve code", "find convention violations" 같은 요청에 사용.
---

# refactoring-assistant

## Description

Automated refactoring assistant for the fineadple-server project that analyzes code against team conventions and applies systematic improvements with **multi-module impact analysis**.

This skill should be used when users request code refactoring, convention compliance checking, or code quality improvements. Trigger phrases include "refactor", "apply conventions", "check code quality", "improve code", or "find convention violations".

## Key Features

1. **Multi-Module Impact Analysis**: Automatically detects and updates all usages across dependent modules when changing method names or signatures
2. **Test Code Coverage**: Includes both production and test code in refactoring scope
3. **Compilation & Test Verification**: Validates changes by running compilation and tests
4. **Convention Compliance**: Follows `.docs/conventions/code-convention.md` guidelines strictly

## Project Module Structure

```
fineadple_common (공통 모듈: 상수, enum, 예외처리, util, 암호화)
    ↓
fineadple_infrastructure (인프라 모듈)
    ↓
    ├─ fineadple_b2c_api (API 서버 메인 모듈)
    ├─ fineadple_advertiser_center_api (광고주센터 API 모듈)
    ├─ fineadple_authentication_api (인증 API 모듈)
    ├─ fineadple_backoffice_api (Admin 서버 모듈)
    ├─ fineadple_batch (배치 서버 모듈)
    ├─ fineadple_crawler_api (인스타그램 크롤러 서버 모듈)
    ├─ fineadple_notification_api (알림톡 서버 모듈)
    └─ fineadple_lambda (AWS Lambda 모듈)
```

## Refactoring Process

### Phase 1: Pre-Analysis (영향도 분석)

**목적**: 변경 전 전체 프로젝트에서 영향 받는 파일과 모듈을 파악

1. **메서드명/클래스명 변경 시 전체 검색**
   ```bash
   # 프로덕션 코드 검색
   grep -r "oldMethodName" --include="*.kt" --include="*.java" */src/main/

   # 테스트 코드 검색
   grep -r "oldMethodName" --include="*.kt" --include="*.java" */src/test/
   ```

2. **멀티 모듈 의존성 확인**
   - common, infrastructure 모듈 변경 시 특히 주의
   - settings.gradle.kts에서 전체 모듈 목록 확인
   - 각 모듈의 build.gradle.kts에서 의존성 확인

   영향 범위:
   ```
   fineadple_common 모듈 변경 시 → 모든 모듈 확인 필요
   - fineadple_infrastructure
   - fineadple_b2c_api
   - fineadple_advertiser_center_api
   - fineadple_authentication_api
   - fineadple_backoffice_api
   - fineadple_batch
   - fineadple_crawler_api
   - fineadple_notification_api
   - fineadple_lambda

   fineadple_infrastructure 모듈 변경 시 → common 제외 모든 모듈 확인
   - fineadple_b2c_api ~ fineadple_lambda (위 목록에서 infrastructure 제외)
   ```

3. **영향 받는 파일 목록 생성**
   - 변경할 파일 리스트
   - 영향 받는 모듈 리스트
   - 실행할 테스트 리스트

### Phase 2: Refactoring (리팩토링 실행)

**우선순위 적용**:
1. 로깅 규칙 개선 (낮은 영향도)
2. 메서드 네이밍 변경 (높은 영향도 - Phase 1 분석 필수)
3. 예외 처리 개선 (중간 영향도)

**메서드명 변경 프로세스**:
1. Phase 1에서 파악한 모든 파일에서 일괄 변경
2. Interface와 Implementation 모두 변경
3. 모든 호출 지점 변경 (프로덕션 + 테스트)
4. Import 문 확인 및 정리

### Phase 3: Verification (검증)

1. **컴파일 검증**
   ```bash
   # 영향 받는 모든 모듈 컴파일
   ./gradlew :fineadple_common:compileKotlin :fineadple_infrastructure:compileKotlin :fineadple_backoffice_api:compileKotlin :fineadple_batch:compileKotlin

   # 테스트 코드 컴파일
   ./gradlew :fineadple_common:compileTestKotlin :fineadple_backoffice_api:compileTestKotlin
   ```

2. **테스트 실행**
   ```bash
   # 영향 받는 테스트만 선택적 실행
   ./gradlew :fineadple_common:test --tests "*ChangedClassTest"
   ./gradlew :fineadple_batch:test --tests "*AffectedServiceTest"
   ```

3. **검증 체크리스트**
   - [ ] 모든 모듈 컴파일 성공
   - [ ] 영향 받는 테스트 모두 통과
   - [ ] 변경 누락된 파일이 없는지 재확인 (grep으로 이전 이름 검색)
   - [ ] Import 오류 없음

### Phase 4: Documentation (문서화)

**커밋 메시지 형식**:
```
refactor: [변경 내용 요약]

상세 변경 사항:
- [카테고리1] 변경 내용 (영향 받은 모듈: module1, module2)
- [카테고리2] 변경 내용

영향 받은 파일: XX개
영향 받은 모듈: module1, module2, module3

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

## Common Pitfalls (흔한 실수 방지)

### 실수 1: 단일 모듈만 확인
```
back_office_api 모듈의 Reader 인터페이스만 변경하고
→ 다른 모듈의 호출 코드는 변경하지 않음
```

올바른 방법:
```
1. grep으로 전체 프로젝트 검색
2. 모든 호출 지점 리스트업
3. 프로덕션 + 테스트 코드 모두 변경
4. 모든 영향 받은 모듈 컴파일 및 테스트
```

### 실수 2: 테스트 코드 누락
```
프로덕션 코드만 변경하고
→ 테스트 코드의 메서드 호출은 그대로 둠
```

올바른 방법:
```
1. */src/main/ 검색
2. */src/test/ 검색
3. 양쪽 모두 변경
```

### 실수 3: 검증 없이 커밋
```
변경 후 컴파일이나 테스트 없이 바로 커밋
```

올바른 방법:
```
1. 영향 받은 모듈 모두 컴파일
2. 관련 테스트 실행
3. 성공 확인 후 커밋
```

## Multi-Module Refactoring Checklist

**common 모듈 변경 시**:
- [ ] settings.gradle.kts에서 모든 모듈 확인
- [ ] 각 모듈의 src/main과 src/test 모두 검색
- [ ] 전체 모듈 확인 (fineadple_infrastructure, fineadple_b2c_api, fineadple_advertiser_center_api, fineadple_authentication_api, fineadple_backoffice_api, fineadple_batch, fineadple_crawler_api, fineadple_notification_api, fineadple_lambda)

**infrastructure 모듈 변경 시**:
- [ ] DB Entity 사용하는 모든 모듈 확인
- [ ] Repository 사용하는 모든 Service 확인
- [ ] 배치 관련 변경 시 fineadple_batch 확인
- [ ] 크롤러 인터페이스 변경 시 fineadple_crawler_api 확인

**domain interface 변경 시**:
- [ ] 해당 interface를 구현하는 모든 Impl 클래스 확인
- [ ] 해당 interface를 사용하는 모든 Service 확인
- [ ] 테스트 코드의 mock 객체 확인

## Code Convention References

이 스킬은 `.docs/conventions/code-convention.md`의 컨벤션을 준수합니다:

1. **로직 단순화 원칙**: Early Return, when 식, 선언적 코드 지향
2. **아키텍처 개선 원칙**: 계층별 책임 분리, 인터페이스 최소화, DIP 실용적 적용
3. **예외 처리 원칙**: 엔티티 조회 예외 패턴, 커스텀 예외 사용
4. **테스트 전략**: Fixture 패턴, Given-When-Then 구조
5. **가독성 향상 원칙**: 네이밍, 로깅, 코드 구조
6. **레이어별 책임 분리**: Presentation → Service → Domain → Infrastructure
7. **Facade 패턴**: 복합 비즈니스 로직 조합 시 사용

## Examples

### Example 1: Method Rename in Common Module

```kotlin
// Before: common/VendorTaskUtil.kt
fun isLowMinVendorQuantity(quantity: Int, min: Int): Boolean

// Step 1: Search usage
// grep -r "isLowMinVendorQuantity" --include="*.kt" .
// Found in:
// - task_scheduler/CreateStartTaskScheduleService.kt
// - common/VendorTaskUtilTest.kt

// Step 2: Rename everywhere
// - common/VendorTaskUtil.kt
// - task_scheduler/CreateStartTaskScheduleService.kt (2 usages)
// - common/VendorTaskUtilTest.kt (10 usages)

// Step 3: Verify
// ./gradlew :common:compileKotlin :task_scheduler:compileKotlin
// ./gradlew :common:test --tests "VendorTaskUtilTest"

// After: All files updated
fun isBelowMinimumQuantity(quantity: Int, min: Int): Boolean
```

### Example 2: Adding Custom Exception

```kotlin
// Step 1: Check where NoResultException is used
// grep -r "NoResultException" --include="*.kt" back_office_api/

// Step 2: Add custom exception to common module
// common/exception/Exceptions.kt

// Step 3: Replace in all files
// back_office_api/**/ReaderImpl.kt files

// Step 4: Verify
// ./gradlew :common:compileKotlin :back_office_api:compileKotlin
// ./gradlew :back_office_api:test
```

## Integration with Other Skills

- **commit-helper**: 리팩토링 완료 후 자동으로 커밋 메시지 생성
- **pr-creator**: 리팩토링 브랜치에서 PR 생성 시 변경 내용 자동 요약
- **pr-reviewer**: 리팩토링 PR의 코드 리뷰 수행

## Tips

1. **작은 단위로 리팩토링**: 한 번에 모든 컨벤션을 적용하기보다는 카테고리별로 나누어 진행
2. **검증을 자주**: 각 카테고리 리팩토링 후마다 컴파일 및 테스트 실행
3. **커밋을 자주**: 각 카테고리별로 커밋하여 롤백 가능하도록 유지
4. **문서화**: 왜 변경했는지 커밋 메시지에 명확히 기록

## Troubleshooting

**Q: 메서드명을 변경했는데 일부 모듈에서 컴파일 에러 발생**
A: Phase 1의 전체 검색을 다시 수행하고, 놓친 파일이 있는지 확인

**Q: 테스트가 실패함**
A: 테스트 코드에서 메서드명 변경을 놓쳤을 가능성. */src/test/ 경로 재검색

**Q: 어떤 모듈이 영향을 받는지 모르겠음**
A:
```bash
# 의존성 트리 확인
./gradlew :moduleName:dependencies

# 전체 모듈 목록
cat settings.gradle.kts | grep include
```

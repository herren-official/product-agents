---
name: b2b-backend-refactor-code-style
description: 코드 스타일 가이드 기반으로 지정된 파일들을 리팩토링
argument-hint: [파일 목록 또는 패키지 경로]
---

코드 스타일 가이드 기반으로 지정된 파일들을 리팩토링한다.

## 입력

$ARGUMENTS — 리팩토링 대상 파일 목록 또는 패키지 경로. 없으면 현재 브랜치에서 변경된 파일을 대상으로 한다.

## 실행 절차

### Step 1: 대상 파일 수집

- 인자가 있으면 해당 파일/패키지의 Java/Kotlin 파일을 대상으로 한다
- 인자가 없으면 `git diff --name-only develop...HEAD` 로 변경 파일 목록 수집
- 테스트 파일은 별도 분류 (src/test/)

### Step 2: 코드 스타일 가이드 로드

가이드 파일이 존재하면 읽고, 없으면 아래 임베디드 체크리스트만으로 진행한다.

```bash
# 우선순위 1: 사용자 로컬 가이드
GUIDE=~/herren-repo/code-style-guide.md
[ -f "$GUIDE" ] || GUIDE=  # 없으면 빈 값 → 아래 임베디드 체크리스트만 사용
```

**가이드가 없을 때 동작**: Step 3의 임베디드 체크리스트 24개 항목이 단일 진실 공급원이 된다. 가이드는 보충 자료일 뿐이며, 부재해도 기본 검사는 수행된다.

### Step 3: 체크리스트 검사

각 파일에 대해 다음 항목을 검사한다:

**Entity 파일:**
1. `@Setter` / `@Data` 사용 여부 (금지)
2. `@NoArgsConstructor(access = AccessLevel.PROTECTED)` 존재 여부
3. 어노테이션 순서: `@NoArgsConstructor` -> `@AllArgsConstructor` -> `@Builder` -> `@Getter` -> JPA 매핑 -> `@Entity`
4. enum 필드에 `@Enumerated(EnumType.STRING)` 적용 여부
5. String으로 저장된 enum 후보 필드 감지 (type, status, category 등)
6. wildcard import (`.*`) 사용 여부 (금지)
7. `domain/` 레이어에 위치하는지 확인

**Info/DTO 파일:**
8. 외부 클래스 `@NoArgsConstructor(access = AccessLevel.PRIVATE)` 존재 여부
9. `of(Entity)` 팩토리 메서드 존재 여부
10. 필드 5개 이하: private 생성자 + of() 팩토리 / 필드 6개 이상: `@Builder` 허용
11. Response DTO에서 enum을 `.name()` 으로 String 변환하지 않는지

**Reader/Store 구현체:**
12. Reader: 순수 조회만 담당 (검증/필터링 로직 없음)
13. Store: Entity 정적 팩토리 + 비즈니스 메서드에 위임 (직접 빌더 사용 금지)
14. `.name()` 호출로 enum->String 변환하는 곳 감지 (Repository 파라미터 포함)
15. 변경 전/후 상태 `log.debug` 로깅 여부

**Repository:**
16. 단건 조회는 `Optional<T>` 별도 메서드 (목록 메서드 재활용 금지)
17. enum 파라미터 타입 사용 (String 금지)

**Facade:**
18. 얇은 위임자 역할만 하는지 (비즈니스 로직 없음)
19. `@ApplicationService` 사용 여부

**테스트 파일:**
20. given-when-then 구조
21. `@DisplayName` 한글
22. AssertJ 사용 (`assertThat`)

**공통:**
23. wildcard import (`.*`) 금지
24. 클래스 레벨 JavaDoc (한 줄 설명)

### Step 4: 결과 보고

각 파일별로 결과를 다음 형식으로 보고한다:

```
## {파일명}

### PASS (N건)
- 항목명

### ISSUE (N건) — 수정 필요
- 항목명: 현재 상태 -> 수정 방안

### WARNING (N건) — 참고
- 항목명: 설명
```

### Step 5: 자동 수정

ISSUE 처리는 두 등급으로 나눈다.

**🟢 자동 적용 (안전, 별도 확인 불필요)**
- 어노테이션 순서 재배치 (의미 동일)
- `@Enumerated(EnumType.STRING)` 추가 (Entity 빌드/리플렉션 시점 안전)

**🟡 사용자 확인 후 적용 (의미 변경 가능)**
- wildcard import → 개별 import 변환 (이름 충돌 가능성)
- `.name()` 호출 제거 (호출처 시그니처 변경, 호출 사이트 영향)
- 로깅 추가 (운영/성능에 영향)

위 🟡 항목은 each 변경마다 before/after diff를 사용자에게 제시하고 명시적 승인을 받은 후 적용한다.

### 수정 후 빌드 검증

1. **컴파일 확인** (필수): `./gradlew :{모듈명}:compileJava`
2. **단위 테스트 실행** (권장): `./gradlew :{모듈명}:test`
   - 테스트 시간이 길거나 변경 범위가 좁으면 사용자에게 실행 여부를 묻고 진행 (`y/n`).
   - 실패한 테스트가 있으면 수정 사항 검토 후 다시 실행한다.

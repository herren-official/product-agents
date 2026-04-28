---
name: b2b-backend-test-write
description: 대상 코드의 테스트 코드를 분석, 도출하고 실제 파일로 작성한다.
user-invocable: true
allowed-tools: Read, Edit, Write, Grep, Glob, Bash
---

대상 코드의 테스트 코드를 작성해라.

## 입력

$ARGUMENTS

- 인자가 파일 경로이면 해당 파일을 대상으로 한다.
- 인자가 클래스명이면 프로젝트에서 해당 클래스를 검색하여 대상으로 한다.
- 인자가 없으면 현재 브랜치와 develop 브랜치를 비교(`git diff develop...HEAD --name-only`)하여 추가/변경된 프로덕션 코드 파일(.java, .kt)을 대상으로 한다. 테스트 파일(`src/test/`)은 대상에서 제외한다. develop 브랜치가 없으면 main, master 순으로 시도한다.

## 절차

### Step 1: 프로젝트 환경 파악
다음을 확인한다:
- 빌드 도구: `build.gradle.kts` / `build.gradle` / `pom.xml`
- 언어: Java / Kotlin (대상 파일 확장자로 판단)
- Spring Boot 버전: `spring-boot-starter-parent` 또는 `spring-boot-dependencies` 버전 확인
  - 2.x → `javax.*` 패키지 사용
  - 3.x → `jakarta.*` 패키지 사용
- 테스트 라이브러리: MockK / Mockito / AssertJ / JUnit5
- 기존 테스트 파일의 패턴과 네이밍 컨벤션

### Step 2: 테스트 계획 파일 및 기존 테스트 확인
- 현재 브랜치명을 `git branch --show-current`로 가져오고, `/`를 `-`로 치환한다.
- 프로젝트 루트의 `.claude/test/{branch-name}-test-plan.md` 파일이 존재하면 읽어 도출된 케이스 목록을 참조한다.
- `src/test/` 하위에서 대상 클래스의 기존 테스트 파일을 검색한다.
- 있으면 읽고, 기존 스타일(네이밍, fixture 방식, assertion 스타일)을 따른다.
- 없으면 프로젝트 내 다른 테스트 파일 1~2개를 참고하여 컨벤션을 파악한다.

### Step 3: 테스트 케이스 도출
테스트 계획 파일이 있으면 해당 케이스 목록을 기준으로 하고, 없으면 직접 도출한다.
다음 관점으로 케이스를 도출한다:
- 정상 경로 (happy path)
- 경계값 (빈 리스트, null, 최대값)
- 예외/에러 (비즈니스 예외, 시스템 예외)
- 보안 (권한 검증이 있는 경우)
- 동시성 (대상 코드에 `@Version`, `synchronized`, `Lock`, `AtomicXxx`, `CompletableFuture` 등이 있는 경우)

### Step 4: 테스트 코드 작성
다음 규칙을 따른다. `test-writer` Skill의 코드 패턴이 로드되어 있으면 해당 패턴을 우선 따른다.

**공통:**
- 테스트 메서드명: `should_[결과]_when_[조건]` 패턴 또는 기존 프로젝트 컨벤션
- 구조: Given-When-Then 또는 Arrange-Act-Assert
- 한 테스트에 하나의 검증 포인트
- 테스트 간 상태 공유 금지

**테스트 유형별 어노테이션:**
- Unit: `@ExtendWith(MockitoExtension.class)` 또는 `@ExtendWith(MockKExtension::class)`
- Controller Slice: `@WebMvcTest(FooController.class)`
- Repository Slice: `@DataJpaTest` + `@AutoConfigureTestDatabase(replace = Replace.NONE)` (Testcontainers 사용 시)
- Integration: `@SpringBootTest` + `@Testcontainers` (필요 시)

### Step 5: 파일 생성
- 테스트 파일 경로: `src/test/[java|kotlin]/` 하위, 대상 클래스와 동일한 패키지
- 파일명: `[대상클래스명]Test.[java|kt]`
- 기존 파일이 있으면 기존 파일에 누락된 케이스만 추가한다. 기존 테스트와 동일한 메서드/시나리오를 검증하는 케이스가 이미 있으면 추가하지 않는다. 기존 케이스의 assertion이 부족한 경우에만 보강한다.
- 추가 시 위치는 클래스 내 마지막 테스트 메서드 뒤로 하고, 필요한 import 문을 파일 상단에 추가한다.

### Step 6: 컴파일 확인
- 작성한 테스트 파일의 import 문과 어노테이션이 프로젝트 의존성과 일치하는지 확인한다.
- 명백한 컴파일 에러가 있으면 수정한다.

## 제약

- 프로젝트의 기존 테스트 컨벤션을 최우선으로 따른다.
- 프로덕션 코드를 수정하지 않는다.
- 대상 파일을 찾을 수 없으면 "대상 파일을 찾을 수 없습니다. 파일 경로 또는 클래스명을 지정해 주세요."를 출력한다.
- develop/main/master 브랜치를 모두 찾을 수 없으면 "기준 브랜치를 찾을 수 없습니다. 대상 파일을 직접 지정해 주세요."를 출력한다.
- 빌드 도구나 Spring Boot 버전을 확인할 수 없으면 사용자에게 확인을 요청한다.

## 완료 후 출력

```markdown
## 테스트 작성 완료

### 생성/수정된 파일
| 파일 | 변경 내용 |
|---|---|
| `[경로]` | 신규 생성 / [N]개 케이스 추가 |

### 작성된 테스트 메서드
- Unit: [N]개
- Slice: [N]개
- Integration: [N]개

### 다음 단계
- 작성된 테스트를 리뷰하려면 `/test-review [테스트 클래스]`를 실행하세요.
- 실행까지 포함한 품질 검증이 필요하면 "테스트 검증해줘"라고 요청하세요.
```

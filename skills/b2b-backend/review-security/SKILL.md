---
name: b2b-backend-review-security
description: 보안 관점 집중 코드 리뷰 (Injection, 인증/인가, 민감정보)
argument-hint: [file-path]
user-invocable: true
allowed-tools: Read, Bash, Grep, Glob
---

보안 관점에서 코드를 집중 리뷰해라.

## 입력

$ARGUMENTS

- 인자가 파일 경로이면 해당 파일을 대상으로 한다.
- 인자가 없으면 현재 브랜치와 develop 브랜치를 비교(`git diff develop...HEAD`)하여 변경된 파일을 대상으로 한다. develop 브랜치가 없으면 main, master 순으로 시도한다.

## 절차

### Step 1: 변경 코드 읽기
- 변경된 파일과 diff를 읽는다.
- 설정 파일(application.yml, SecurityConfig 등)이 변경되었으면 함께 읽는다.
- Spring Security 설정, CORS 설정, 필터 체인 구성을 확인한다.

### Step 2: 보안 체크리스트

**Injection:**
- SQL Injection: Native Query에 문자열 결합으로 파라미터를 넣는가? (`:param` 바인딩 또는 `?` 사용 확인)
- JPQL Injection: JPQL에 문자열 결합이 있는가?
- Command Injection: `Runtime.exec()`, `ProcessBuilder`에 사용자 입력이 들어가는가?
- Log Injection: 사용자 입력이 로그에 그대로 출력되는가? (CRLF 삽입 가능)

**인증/인가:**
- 새 API 엔드포인트에 인증이 적용되어 있는가? (`@PreAuthorize`, `@Secured`, SecurityConfig)
- 리소스 소유자 검증이 있는가? (다른 사용자의 데이터에 접근 가능한지)
- IDOR(Insecure Direct Object Reference): ID 파라미터로 타인의 리소스에 접근 가능한가?
- 관리자 전용 API에 권한 체크가 있는가?

**데이터 노출:**
- 민감정보(비밀번호, 토큰, API 키)가 코드에 하드코딩되어 있는가?
- 응답 DTO에 민감 필드(비밀번호 해시, 내부 ID 등)가 포함되는가?
- 에러 응답에 스택트레이스나 내부 구현 정보가 노출되는가?
- 로그에 민감정보가 출력되는가?

**입력 검증:**
- `@Valid` / `@Validated`가 컨트롤러 파라미터에 적용되어 있는가?
- 파일 업로드 시 파일 타입, 크기 제한이 있는가?
- URL 리다이렉트에 사용자 입력이 들어가는가? (Open Redirect)
- HTML 출력에 사용자 입력이 인코딩 없이 포함되는가? (XSS)

**설정:**
- CORS 설정이 `allowedOrigins("*")`로 되어 있는가?
- CSRF 보호가 적절한가? (REST API는 비활성화 가능, 세션 기반은 활성화 필요)
- HTTPS 강제 설정이 있는가?
- 세션 관리: 세션 고정 공격 방지 설정이 있는가?

**의존성:**
- 새로 추가된 라이브러리에 알려진 취약점(CVE)이 있는가?
- 라이선스가 프로젝트와 호환되는가?

### Step 3: 심각도 분류
- **CRITICAL**: 즉시 악용 가능한 취약점 (SQL Injection, 인증 우회, 민감정보 노출)
- **WARNING**: 조건부 악용 가능 또는 방어 심층 부족 (IDOR, 느슨한 입력 검증)
- **INFO**: 보안 강화 권장 (로그 개선, 헤더 추가 등)

## 출력 형식

```markdown
## 보안 리뷰

### 변경 요약
- 변경 파일: [N]개
- 언어: [Java / Kotlin / 혼재]
- Spring Boot: [버전 또는 "확인 불가"]
- 새 API 엔드포인트: [N]개
- 설정 변경: [있음/없음]

### 보안 점검 결과
| # | 심각도 | 카테고리 | 파일:라인 | 취약점 | 공격 시나리오 | 개선안 |
|---|--------|----------|----------|--------|-------------|--------|
| 1 | CRITICAL | Injection | OrderRepo.kt:30 | Native Query 문자열 결합 | 검색어에 SQL 삽입 | 파라미터 바인딩 사용 |
| 2 | WARNING | 인가 | OrderController.kt:15 | 리소스 소유자 미검증 | 타인 주문 조회 가능 | 소유자 검증 로직 추가 |

### 수정 코드 (CRITICAL / WARNING)
\`\`\`[java|kotlin]
// 수정 전
...
// 수정 후
...
\`\`\`

### 요약
- CRITICAL: [N]개 / WARNING: [N]개 / INFO: [N]개
- 전체 판정: [안전 / 수정 필요 / 긴급 수정 필요]

### 다음 단계
- 종합 리뷰가 필요하면 `/review`를 실행하세요.
- 성능 리뷰가 필요하면 `/review-perf`를 실행하세요.
- 복잡도 개선이 필요하면 `/simplify`를 실행하세요.
- 대규모 변경의 영향 범위 분석이 필요하면 "심층 리뷰해줘"라고 요청하세요.
```

## 제약

- 프로덕션 코드를 직접 수정하지 않는다. 수정 코드를 출력으로 제시한다.
- 보안 취약점의 공격 시나리오를 구체적으로 기술한다 (단, 실제 공격 코드는 제공하지 않는다).
- 확실하지 않은 취약점은 "확인 필요"로 표시하고, 확인 방법을 제시한다.
- develop/main/master 브랜치를 모두 찾을 수 없으면 "기준 브랜치를 찾을 수 없습니다. 대상 파일을 직접 지정해 주세요."를 출력한다.

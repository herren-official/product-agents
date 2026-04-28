---
name: b2b-backend-review-checklist
description: PR 머지 전 최종 점검 체크리스트
argument-hint: [file-path]
user-invocable: true
allowed-tools: Read, Bash, Grep, Glob
---

PR 머지 전 최종 점검을 수행해라. 코드 품질이 아닌 배포/운영 관점의 누락 항목을 확인한다.

## 입력

$ARGUMENTS

- 인자가 파일 경로이면 해당 파일과 관련된 항목만 점검한다.
- 인자가 없으면 현재 브랜치와 develop 브랜치를 비교(`git diff develop...HEAD --name-only`)하여 변경된 파일을 대상으로 한다. develop 브랜치가 없으면 main, master 순으로 시도한다.

## 절차

### Step 1: 변경 범위 파악
- `git diff develop...HEAD --stat`으로 변경 파일 목록과 규모를 확인한다.
- `git log develop...HEAD --oneline`으로 커밋 이력을 확인한다.
- 변경된 파일의 유형을 분류한다: 소스 코드, 설정 파일, 마이그레이션, 빌드 설정, 문서.

### Step 2: 체크리스트 점검

**DB / 마이그레이션:**
- Entity 필드가 추가/변경/삭제되었는데 마이그레이션 파일(Liquibase changelog, Flyway migration)이 없는가?
- NOT NULL 컬럼 추가 시 기존 데이터에 대한 DEFAULT 값 또는 데이터 마이그레이션이 있는가?
- 인덱스 추가/삭제가 필요한 쿼리 변경이 있는가?
- 마이그레이션 파일이 있다면 롤백 스크립트(rollback section)가 있는가?
- Entity 제약 조건 어노테이션(@Column nullable/unique/length, @Table uniqueConstraints/indexes)이 마이그레이션 DDL과 일치하는가?

**설정 / 환경 변수:**
- `application.yml` 또는 `application.properties`에 새 설정이 추가되었는데, 환경별(dev/staging/prod) 설정이 누락되지 않았는가?
- 새 환경 변수가 필요한데 `.env.example` 또는 배포 설정에 반영되지 않았는가?
- 민감정보(비밀번호, API 키)가 설정 파일에 하드코딩되어 있지 않은가? (vault, secrets manager 사용 확인)

**의존성:**
- `build.gradle` 또는 `pom.xml`에 새 의존성이 추가되었는가?
- 추가된 의존성의 라이선스가 프로젝트와 호환되는가? (GPL 라이브러리 주의)
- 기존 의존성 버전이 변경되었는가? (Major 버전 업그레이드 시 breaking change 확인)

**API 변경:**
- 기존 API 엔드포인트의 URL, HTTP 메서드, 요청/응답 필드가 변경되었는가?
- 변경된 API에 대한 API 문서(Swagger/OpenAPI spec)가 업데이트되었는가?
- 하위 호환성이 깨지는 변경이 있다면 클라이언트(프론트엔드, 모바일, 외부 연동)에 사전 공유되었는가?

**메시지 / 이벤트:**
- Kafka topic, SQS queue 등 메시지 포맷이 변경되었는가?
- 메시지 포맷 변경 시 소비자(consumer) 측의 하위 호환성이 유지되는가?
- 새 topic/queue가 추가되었는데 인프라 생성이 필요한가?

**캐시 / 세션:**
- 캐시 키 구조가 변경되어 기존 캐시 무효화가 필요한가?
- 세션 구조가 변경되어 기존 세션이 깨질 수 있는가?
- Redis 스키마 변경이 있는가?

**배포 순서:**
- DB 마이그레이션이 API 서버 배포 전에 실행되어야 하는가?
- 여러 서비스가 동시에 배포되어야 하는가? (의존 순서가 있는가?)
- Feature flag로 단계적 롤아웃이 필요한 변경인가?

**테스트:**
- 변경된 코드에 대응하는 테스트가 있는가? (신규 기능이면 테스트 추가 여부)
- 기존 테스트가 변경 사항을 반영하여 업데이트되었는가?

### Step 3: 판정
각 항목에 대해:
- **OK**: 해당 없음 또는 올바르게 처리됨
- **누락**: 필요한 조치가 빠져있음 (조치 내용 명시)
- **확인 필요**: 코드만으로 판단 불가, 수동 확인 필요 (확인 방법 명시)

## 심각도 분류
- 🔴 필수 수정 (CRITICAL): 장애, 보안 취약점, 데이터 손실 가능성
- 🟡 권장 수정 (WARNING): 성능 저하, 유지보수 비용 증가, 안티패턴
- 🟢 참고 (INFO): 더 나은 대안, 스타일, 개선 아이디어

## 출력 형식

```markdown
## 머지 전 체크리스트

### 변경 요약
- 커밋 수: [N]개
- 변경 파일: [N]개
- 언어: [Java / Kotlin / 혼재]
- Spring Boot: [버전 또는 "확인 불가"]

### 점검 결과
| # | 카테고리 | 항목 | 상태 | 비고 |
|---|----------|------|------|------|
| 1 | DB | 마이그레이션 파일 존재 | OK | V20240301__add_order_status.sql |
| 2 | DB | NOT NULL 기본값 | 누락 | status 컬럼에 DEFAULT 값 필요 |
| 3 | 설정 | 환경별 설정 | 확인 필요 | prod 환경의 redis.url 수동 확인 |
| 4 | API | API 문서 업데이트 | 누락 | /api/orders 응답에 새 필드 추가됨 |
| 5 | 배포 | 마이그레이션 선행 실행 | OK | API 서버 배포 전 실행 필요 |

### 누락 항목 상세
#### #2 NOT NULL 기본값
- 파일: `V20240301__add_order_status.sql`
- 문제: `ALTER TABLE orders ADD COLUMN status VARCHAR(20) NOT NULL` — 기존 데이터에 DEFAULT 값 없음
- 조치: `DEFAULT 'PENDING'` 추가 또는 데이터 마이그레이션 스크립트 작성

### 요약
- OK: [N]개 / 누락: [N]개 / 확인 필요: [N]개
- 전체 판정: [머지 가능 / 조치 후 머지 / 머지 보류]

### 다음 단계
- 코드 품질 리뷰가 필요하면 `/review`를 실행하세요.
- 보안 점검이 필요하면 `/review-security`를 실행하세요.
- 성능 점검이 필요하면 `/review-perf`를 실행하세요.
- 대규모 변경의 영향 범위 분석이 필요하면 "심층 리뷰해줘"라고 요청하세요.
```

## 제약

- 프로덕션 코드를 직접 수정하지 않는다. 누락 항목과 조치 방법을 출력으로 제시한다.
- 코드 품질(트랜잭션, N+1 등)은 점검하지 않는다. 배포/운영 관점 누락 항목에 집중한다.
- 코드만으로 확인 불가능한 항목(인프라 설정, 외부 팀 공유 여부 등)은 "확인 필요"로 표시하고 확인 방법을 제시한다.
- develop/main/master 브랜치를 모두 찾을 수 없으면 "기준 브랜치를 찾을 수 없습니다. 대상 파일을 직접 지정해 주세요."를 출력한다.

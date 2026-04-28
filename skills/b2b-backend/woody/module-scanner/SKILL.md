---
name: b2b-backend-module-scanner
description: 지정된 모듈의 기술 스택(Spring Boot 버전, JPA annotation 등)을 build.gradle.kts에서 직접 확인하는 스킬. CLAUDE.md 테이블과 교차 검증하여 불일치를 경고한다.
---

# 모듈 기술 스택 스캐너 (module-scanner)

## 역할

지정된 모듈의 build.gradle.kts를 직접 읽어 기술 스택을 파악한다. CLAUDE.md의 모듈 테이블은 outdated될 수 있으므로, 실제 빌드 파일 기준으로 정확한 정보를 제공한다.

## 입력

- **모듈명 목록**: 예) `["gongbiz-notification", "gongbiz-crm-b2b-backend", "gongbiz-notification-orchestrator"]`
- **프로젝트 루트**: 절대 경로
- **저장 경로**: `module_context.md`를 저장할 절대 경로

## 출력

- `{저장경로}/module_context.md` — 모듈별 기술 컨텍스트 테이블

## 워크플로우

### Step 1: 모듈별 build.gradle.kts 분석

각 모듈에 대해:

1. `{프로젝트루트}/{모듈명}/build.gradle.kts` Read
   - 파일 미존재 시 → 라이브러리 모듈로 판정 (Spring Boot 미사용)
2. **Spring Boot 버전 추출**:
   ```
   plugins 블록에서:
   id("org.springframework.boot") version "X.Y.Z"
   ```
   - version 없이 `id("org.springframework.boot")`만 있으면 → 루트 프로젝트 또는 buildSrc에서 버전 확인
3. **주요 의존성 식별**:
   - JPA: `spring-boot-starter-data-jpa` 존재 여부
   - MyBatis: `mybatis` 존재 여부
   - QueryDSL: `querydsl-apt` 또는 `querydsl-jpa` 존재 여부
   - SQS: `spring-cloud-aws-sqs` 또는 `aws-messaging` 존재 여부
   - Kafka: `spring-kafka` 존재 여부
   - Redis: `spring-boot-starter-data-redis` 존재 여부

### Step 2: javax vs jakarta 판별

1. `{프로젝트루트}/{모듈명}/src/main` 하위에서 Grep:
   - `javax.persistence` 패턴 count
   - `jakarta.persistence` 패턴 count
2. 더 많은 쪽으로 판정
3. 둘 다 0이면 → "JPA 미사용" 또는 라이브러리 모듈

### Step 3: CLAUDE.md 교차 검증

1. `{프로젝트루트}/CLAUDE.md` Read
2. "## ⚠️ 중요: 모듈별 Spring Boot 버전" 섹션의 테이블 파싱
3. 각 모듈에 대해:
   - CLAUDE.md 기재 SB 버전 vs build.gradle.kts 실제 버전 비교
   - **불일치 시**: `⚠️ CLAUDE.md 불일치: {모듈} — 문서: {CLAUDE.md 버전}, 실제: {실제 버전}` 경고

### Step 4: 결과 저장

Write 도구로 `{저장경로}/module_context.md` 생성:

```markdown
# 모듈 기술 컨텍스트

> 생성일: {날짜}
> 기준 브랜치: {현재 브랜치}

## 모듈별 기술 스택

| 모듈 | Spring Boot | JPA Annotation | 주요 의존성 | CLAUDE.md 일치 |
|------|------------|----------------|-----------|---------------|
| gongbiz-notification | 3.3.2 | jakarta.* | JPA, SQS | ⚠️ 불일치 (문서: 2.7.10) |
| gongbiz-crm-b2b-backend | 2.7.10 | javax.* | JPA, MyBatis, QueryDSL | ✅ 일치 |
| ... | ... | ... | ... | ... |

## 경고 사항

- ⚠️ gongbiz-notification: CLAUDE.md에 2.7.10으로 기재되어 있으나 실제 3.3.2
- ...

## 에이전트 참고사항

- 신규 엔티티 작성 시 해당 모듈의 JPA Annotation을 따를 것
- 모듈 간 의존성 추가 시 SB 버전 호환성 확인 필요
```

### Step 5: 검증

1. 모든 입력 모듈이 결과 테이블에 포함되었는지 확인
2. 경고 건수 출력
3. 결과 요약 보고

## 에러 처리

| 상황 | 대응 |
|------|------|
| build.gradle.kts 미존재 | 라이브러리 모듈로 판정, SB 버전 "N/A" |
| CLAUDE.md 테이블 파싱 실패 | 교차 검증 건너뛰고 경고 |
| 모듈 디렉토리 미존재 | "모듈 미존재" 표시 + 오타 가능성 경고 |

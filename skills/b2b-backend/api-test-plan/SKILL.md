---
name: b2b-backend-api-test-plan
description: |
  브랜치 변경 코드 분석 → 12개 섹션 (P0/F1..Fn/X1..Xn/E1..En ID 체계) 테스트 플랜 생성.
  변경 파일 20개 이하 경량 모드 (code-analyzer + cross-module-detector), 21개 이상 분산 모드 (layer-analyzer 3 병렬) 자동 분기.
  다음 상황에서 사용할 것:
  - 브랜치의 변경 사항에 대한 QA 테스트 플랜을 자동 생성할 때
  - API 변경 후 multi-step Flow 와 모니터링 설정이 포함된 플랜이 필요할 때
  다음 상황에서는 사용하지 않을 것:
  - 단위/통합 테스트 코드를 작성할 때
  - 기존 플랜 기반 모니터링만 할 때 (/monitor 커맨드 사용)
allowed-tools: Read, Glob, Bash, Agent, Write
user-invocable: true
---

$ARGUMENTS 브랜치의 변경 코드를 분석하여 12개 섹션 + ID 체계 (`P0` / `F1..Fn` / `X1..Xn` / `E1..En`) 의 유즈케이스 테스트 플랜을 생성한다.

> **용어 구분**: 본 커맨드의 "워크플로우 Phase 1~5" 는 **실행 단계** (Phase 1=코드 분석, Phase 2=시나리오, ...) 의미이다. **산출물 ID 체계** (`P0` / `F1..Fn` / `X1..Xn` / `E1..En`) 와 다르다. 산출물 내부 ID 에는 "Phase" 표현을 절대 사용하지 않는다 (P0 외).

## 입력 검증
- `$ARGUMENTS`에서 브랜치명과 옵션을 추출한다.
- 비어있으면 "브랜치명을 입력해주세요. 예: /api-test-plan feature/fcm-multi-device"를 출력하고 중단한다.
- 브랜치명을 `{branch}`로 저장한다.
- 옵션에 따라 실행 모드를 결정한다:
  - `--analyze-only`: 코드 분석만 실행 (Phase 1만)
  - `--review-only [플랜파일]`: 기존 플랜의 완결성 검증만 실행 (Phase 4만)
  - 옵션 없음: 풀 파이프라인 (기본)

## 사전 조건
- `git fetch origin develop`으로 최신 develop을 확보한다.
- `.claude/plan/` 디렉토리가 없으면 생성한다.

## 스킬 로드
`~/.claude/skills/api-test-plan-knowledge/` 디렉토리의 모든 파일을 읽어 플랜 작성 지식을 로드한다:
- `SKILL.md` — 작성 원칙
- `references/plan-template.md` — 출력 템플릿
- `references/keyword-extraction.md` — 키워드 추출 규칙
- `references/log-source-mapping.md` — 로그 소스 매핑 규칙

스킬 파일을 읽지 못하면 에이전트에게 직접 지시한다: "12개 섹션 (P0 + F1..Fn + X1..Xn + E1..En 구조) 테스트 플랜을 작성하라. 'Phase' 표현은 P0 외 사용 금지."

---

## Phase 1 — 코드 분석 (분석 전략에 따라 분기)

### Step 0: 분석 전략 결정
`git diff --name-only develop...{branch}`로 변경 파일 수를 확인한다.

### 경량 모드 (변경 파일 20개 이하)
Agent 도구를 사용하여 **code-analyzer** → **cross-module-detector** 순서로 순차 호출한다.

**code-analyzer** (1단계):
- 전달 내용: "`{branch}` 브랜치와 `origin/develop` 브랜치의 diff를 분석하라"
- 기대 출력: 변경 API, 테이블, 서비스, 영향 범위, 관련 모듈

**cross-module-detector** (2단계, code-analyzer 완료 후):
- 전달 내용: code-analyzer 결과 전문 + "`{branch}` 브랜치의 교차 모듈 호출을 식별하고 키워드를 보강하라"
- 기대 출력: 교차 모듈 호출 테이블, 보강 키워드, 추가 모니터링 대상 모듈

두 에이전트의 결과를 병합하여 Phase 2에 전달한다.

### 분산 모드 (변경 파일 21개 이상)
변경 파일을 계층별로 사전 분류한다:
- **api**: Controller, DTO, 설정 (`@RestController`, `@Controller`, Request/Response, application.yml)
- **data**: Entity, Repository, 마이그레이션 (`@Entity`, JpaRepository, Flyway/Liquibase)
- **logic**: Service, 배치, Consumer, 외부 연동 (`@Service`, `@Scheduled`, `@SqsListener`, `@KafkaListener`)

Agent 도구를 사용하여 **layer-analyzer** 에이전트를 **3개 병렬** 호출한다.
- 각 에이전트에 해당 계층의 파일 목록과 브랜치명을 전달한다.
- 기대 출력: 계층별 변경 내용, 영향 범위, 키워드, 교차 모듈 호출

3개 결과를 아래 규칙으로 병합하여 Phase 2에 전달한다:
- "변경 API" 테이블: api 계층 결과에서 추출
- "변경 테이블/컬럼" 테이블: data 계층 결과에서 추출
- "변경 서비스 로직" + "배치/Consumer 변경" 테이블: logic 계층 결과에서 추출
- "영향 범위" 테이블: 3개 계층의 영향 범위를 합산
- "교차 모듈 호출" 테이블: logic 계층 결과에서 추출
- "추출 키워드": 3개 계층의 키워드를 합산 (중복 제거)
- **"API 호출 체인" 섹션**: logic 계층의 전체 경로를 기준으로 하고, api 계층의 endpoint 시그니처 + data 계층의 단말 매핑으로 보강. endpoint 별로 zip 매칭하여 정합성 확인. logic 결과가 비어 있으면 "[CRITICAL] 호출 체인 도출 실패" 표시

---

## Phase 2 — 시나리오 작성

Agent 도구를 사용하여 scenario-builder 에이전트를 호출한다.
Phase 1의 전체 출력 텍스트(경량/분산 병합 결과)를 prompt에 포함하여 전달한다.
- 전달 내용: Phase 1 분석 결과 + "`{branch}` 브랜치 소스 코드에서 키워드를 추출하라"
- 기대 출력: Flow별 시나리오 (P0 + F1..Fn), X-IDs, E-IDs, 체크 키워드, 예상 로그 패턴, 단계별 DB 검증 SQL, 상태 전이 테이블

---

## Phase 3 — 인프라 매핑

Agent 도구를 사용하여 infra-mapper 에이전트를 호출한다.
Phase 1의 모듈 목록(교차 모듈 포함)과 Phase 2의 키워드를 prompt에 포함하여 전달한다.
- 전달 내용: 모듈 목록 + Flow별 키워드 (P0, F1..Fn 별)
- 기대 출력: 모니터링 설정 (로그 소스, 수집 명령어, 주기, filter-pattern 실행 블록, devdb SQL, Sentry 검색식)

---

## Phase 4 — 플랜 검토

Agent 도구를 사용하여 plan-reviewer 에이전트를 호출한다.
Phase 1~3의 전체 출력을 조합한 플랜 초안을 prompt에 포함하여 전달한다.
- 전달 내용: 플랜 초안 + "`{branch}` 브랜치 소스 코드와 교차 검증하라"
- 기대 출력: 누락 시나리오, 키워드 검증, 모니터링 설정 검증, 완결성 판정

---

## 에러 처리
- 에이전트가 유효한 출력을 반환하지 않으면 해당 워크플로우 단계의 에러를 사용자에게 보고하고 중단한다.
- `git diff` 실패 시 (브랜치 미존재 등) 에러 메시지를 출력하고 중단한다.
- 에러 해결이 필요하면 `/troubleshoot {에러 메시지}`를 안내한다.

---

## Phase 5 — 최종 플랜 생성

plan-reviewer 의 피드백을 반영하여 최종 플랜을 `.claude/plan/{branch명}-test-plan.md` 에 저장한다.
- 브랜치명의 `/`는 `-` 로 치환한다. 예: `feature/fcm-multi-device` → `feature-fcm-multi-device-test-plan.md`
- `references/plan-template.md` 형식 (12개 섹션) 을 그대로 따른다.
- 작성 책임자 매트릭스는 `SKILL.md` 의 "12개 섹션 작성 책임자 매트릭스" 참조.

### 오케스트레이터 직접 작성 섹션

scenario-builder / infra-mapper 가 채우지 못하는 항목을 오케스트레이터가 직접 작성한다:
- **변경 개요**: code-analyzer 또는 layer-analyzer 결과의 "변경 개요" + git rev-parse 의 HEAD short SHA + 배포 전제 (Liquibase changeset id / 신규 Bean / 프로퍼티) 합산
- **테스트 설계 원칙**: plan-template 의 고정 문구를 사용하되, 신/구 버전 분기 / 동시성 / 외부 연동 등 변경 코드의 특성에 맞춰 1~2 줄 보강
- **QA 결과 요약 표**: P0 / F1..Fn / X1..Xn / E1..En 행만 미리 채우고 결과 컬럼은 `-` 로 둠 (모니터링 후 `/plan-update` 가 채움)

### 12개 섹션 검증

저장 직전 12개 섹션 헤더가 모두 존재하는지 확인한다 (내용 비어도 헤더 유지). 누락 시 plan-reviewer 가 [CRITICAL] 처리한 사례를 반영해 보충.

plan-reviewer 가 CRITICAL 로 지적한 누락 시나리오는 반드시 추가한다.

---

## 최종 출력

```
## 테스트 플랜 생성 완료

### 저장 위치
`.claude/plan/{파일명}`

### 플랜 요약
- 구성: P0 + Flow F{N}개 + 고위험 X{M}개 + 엣지 E{K}개
- 모니터링 대상 모듈: {모듈 목록}
- 주요 키워드: {핵심 키워드 5개 이내}

### 에이전트별 주요 피드백
- code-analyzer: {1줄 요약}
- scenario-builder: {1줄 요약}
- infra-mapper: {1줄 요약}
- plan-reviewer: {1줄 요약}

### 다음 단계
`/monitor {환경} .claude/plan/{파일명}` 으로 모니터링을 시작할 수 있습니다.
```

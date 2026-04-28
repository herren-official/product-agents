---
name: b2b-backend-project-kickoff
description: 새 프로젝트 시작 시 흩어진 컨텍스트(노션 정책, 피그마, DB 구조, 코드베이스, AWS 인프라 등)를 수집하여 통합 리포트와 에이전트 팀 구성 제안을 생성한다.
argument-hint: <epic-project-name>
model: opus
---

$ARGUMENTS 프로젝트에 대해 흩어진 컨텍스트를 수집해 통합 리포트와 에이전트 팀 제안을 생성한다.

## 입력 검증

- `$ARGUMENTS`에서 `epic-project-name`을 추출한다. 비어있으면 사용자에게 `AskUserQuestion`으로 물어본다.
  - 예: `statistics-aggregate-refactor`, `gongbiz-store-v2`
- 입력된 값은 kebab-case로 정규화한다 (공백→`-`, 소문자). 결과를 `{epic}`으로 저장한다.

## 사전 조건

- 출력 디렉터리를 확보한다: `.claude/docs/{epic}/`
  - 이미 존재하면 사용자에게 "기존 디렉터리에 추가/덮어쓰기/중단" 중 선택을 묻는다.

## 스킬 로드

`references/` 하위의 아래 파일을 모두 읽어 스킬 지식을 로드한다.
- `skill-knowledge.md` — 수집 원칙, 작성 가이드, 품질 기준
- `overview-template.md` — `context.md` 템플릿 (얇은 개요)
- `design-draft-template.md` — `design-draft.md` 템플릿 (설계 문서 초안)
- `agent-team-guide.md` — 도메인→에이전트 팀 매핑
- `info-sources.md` — 소스별 수집 방법

스킬 파일 로드에 실패하면 "스킬 파일을 찾을 수 없습니다" 메시지를 출력하고 중단한다.

---

## Phase 0 — 입력 인터뷰

`AskUserQuestion` 도구로 아래 정보를 수집한다. 한 번에 묻지 말고 그룹별로 묶어 2~3회 이내의 질문으로 제한한다.

### 필수 입력 (Group 1)
- **노션 정책 페이지 URL** — 상위 정책 페이지 하나 또는 여러 개 (콤마 구분 허용)
- **피그마 URL 또는 이미지 경로** — URL이면 그대로, 로컬 이미지면 절대 경로
- **GBIZ 에픽 번호** — 예: `GBIZ-26500` (없으면 "없음")

### 선택 입력 (Group 2)
- **DB 관심 도메인 키워드** — 예: `sale, settlement, shop`. 지정 시 `gongbiz-db` 스킬로 스키마 수집
- **AWS 인프라 관심 대상** — 예: `lambda, sqs, kafka-topic, cloudwatch-logs`. 지정 시 해당 리소스만 조회
- **기존 유사 기능 경로** — 레퍼런스로 쓸 파일/PR URL (콤마 구분 허용)

### 선택 입력 (Group 3)
- **Slack 스레드 링크** — 의사결정 히스토리 참조용 (콤마 구분 허용)
- **배포 타겟 모듈 힌트** — 예: `gongbiz-crm-b2b-api`, `gongbiz-crm-b2b-backend`. 모르면 "미정"
- **특이 제약사항** — 컴플라이언스, 마감, freeze 등 자유 서술 (없으면 "없음")

입력이 누락된 필수 항목은 재질문한다. 선택 항목은 건너뛰어도 된다.

---

## Phase 1 — 병렬 정보 수집

아래 작업을 **병렬로** 실행한다. 각 작업의 출력은 `.claude/docs/{epic}/` 하위 개별 md 파일로 저장한다.

### 1-A. 노션 정책 수집 → `policy-summary.md`

- `mcp__claude_ai_Notion__notion-fetch`로 입력받은 각 URL을 조회한다.
- 페이지 본문에 포함된 **하위 노션 링크**를 최대 1단계까지 재귀 수집한다 (무한 재귀 방지).
- 각 페이지의 핵심만 bullet로 요약한다: 배경, 목표, 범위, 비기능 요구사항, 리스크, 담당자.
- 원문 URL을 각 섹션 하단에 출처로 남긴다.

### 1-B. 피그마 분석 → `design-notes.md`

- **URL인 경우** (figma.com/design 또는 figma.com/board):
  1. URL에서 `fileKey`와 `nodeId` 추출 (상세 규칙은 `references/info-sources.md`).
  2. 전체 구조 파악이 필요하면 `mcp__figma__get_metadata`로 프레임 목록 확보.
  3. 각 프레임을 `mcp__figma__get_design_context`로 조회 (코드+스크린샷+힌트 일괄).
  4. 디자인 토큰이 요구사항에 영향을 주면 `mcp__figma__get_variable_defs`.
  5. FigJam 보드(`figma.com/board/...`)는 `mcp__figma__get_figjam`.
- **로컬 이미지 경로인 경우**: `Agent` 도구로 `oh-my-claudecode:vision` 에이전트를 호출하여 화면별 구성/컴포넌트/플로우를 분석.
- 추출 항목: 화면 수, 주요 컴포넌트(Code Connect 매핑 여부 포함), 사용자 플로우, 엣지 UI 상태(빈/에러/로딩), 디자인 토큰.
- 인증 문제가 의심되면 `mcp__figma__whoami`로 상태 확인.

### 1-C. DB 스키마 수집 → `db-schema.md`

- DB 관심 도메인 키워드가 **있으면**: `Skill` 도구로 `gongbiz-db` 스킬을 호출하여 각 키워드 관련 테이블 스키마를 조회한다.
  - 환경은 `dev` 사용 (READ ONLY이므로 안전).
  - 테이블별 컬럼, 인덱스, FK 관계를 정리한다.
- DB 관심 도메인 키워드가 **없으면**: 이 단계를 스킵하고 `db-schema.md`에 "DB 스키마 수집 스킵됨 (키워드 미입력)"만 기록한다.

### 1-D. 코드베이스 분석 → `codebase-map.md`

- `Agent` 도구로 `Explore` 에이전트 (thoroughness=medium) 호출.
  - 전달: 노션 정책 요약의 **도메인 키워드** + 기존 유사 기능 경로(있으면).
  - 기대 출력: 관련 모듈 목록, 유사 기능의 주요 파일/클래스/서비스 경로, 재사용 가능한 패턴, 영향 받을 엔트리포인트.
- 출력에는 파일 경로를 `file_path:line_number` 형식으로 명시한다.

### 1-E. AWS 인프라 분석 → `infra-map.md`

- AWS 관심 대상이 **있으면** Bash로 `aws` CLI를 사용해 수집한다. 예:
  - CloudWatch 로그 그룹: `aws logs describe-log-groups --log-group-name-prefix {prefix}`
  - Lambda: `aws lambda list-functions --query 'Functions[?contains(FunctionName, \`{keyword}\`)]'`
  - SQS: `aws sqs list-queues --queue-name-prefix {prefix}`
  - 기타 소스/주기/식별자를 정리한다.
- AWS 관심 대상이 **없으면**: `infra-map.md`에 "AWS 인프라 수집 스킵됨 (관심 대상 미입력)"만 기록한다.
- AWS 호출 실패 (권한/자격증명) 시 에러를 기록하고 나머지 Phase 진행에는 영향을 주지 않는다.

### 1-F. (선택) Slack 컨텍스트 수집 → `slack-notes.md`

- Slack 스레드 링크가 있으면 `mcp__claude_ai_Slack__slack_read_thread`로 본문을 읽는다.
- 담당자/결정 사항/미해결 질문을 bullet로 요약한다.
- 링크가 없으면 이 파일은 생성하지 않는다.

---

## Phase 2 — 통합 개요 리포트 작성 → `context.md`

Phase 1 결과물을 합쳐 얇은 개요 리포트를 작성한다. 템플릿은 `references/overview-template.md`를 따른다.

핵심 섹션:
- **프로젝트 개요** (에픽 번호, 목표, 범위, 배포 타겟 모듈)
- **정책/요구사항 요약** (policy-summary.md 압축)
- **디자인 요약** (design-notes.md 압축)
- **데이터 모델** (db-schema.md 압축)
- **영향받는 코드** (codebase-map.md 압축)
- **인프라 맵** (infra-map.md 압축)
- **리스크/미결정 사항** (각 수집 단계에서 발견한 불명확성)
- **다음 단계 제안** (design-draft.md 검토 + `/plan` + 구현 플로우)

각 섹션 하단에 상세 파일 링크를 남긴다. 이 문서는 **훑어보기 허브**이므로 200줄 이내로 압축한다.

---

## Phase 3 — 설계 문서 초안 작성 → `design-draft.md`

`references/design-draft-template.md`의 섹션 순서를 **그대로** 따른다. 각 섹션 제목 옆에 반드시 `[자동]` / `[자동·검증 필요]` / `[수동 검토 필요]` 라벨을 붙인다.

### 자동 생성 가능한 부분 (`[자동]`, `[자동·검증 필요]`)
- **1.2 관련 문서 표**: 노션 fetch 과정에서 발견된 링크 나열
- **1.3 대상 모듈/버전**: 노션 정책에 명시된 모듈 + `CLAUDE.md`의 Spring Boot 버전 매핑 참조
- **2.1 AS-IS**: `codebase-map.md`에서 확인된 현재 구조 그림
- **3.2 기존 코드 수정 범위 표**: `codebase-map.md` 기반 영향 지점
- **4.3 마이그레이션 예상 건수**: `db-schema.md` 조회 결과
- **8. 영향 범위 표**: 모듈/레이어 스캔 결과
- **9.1 로그 그룹**: `infra-map.md` 압축
- **10. 논의 필요 항목**: 노션/Slack에서 미결정으로 표기된 항목 자동 추출
- **출처 섹션**: 원문 URL 목록

### 엔지니어가 채워야 할 부분 (`[수동 검토 필요]`)
- **1.4 Phase별 작업 범위**: 초안 표만 제시 + 내용은 "{배포 일정에 따라 분할}" 플레이스홀더
- **2.2 TO-BE 시퀀스**: Mermaid 스켈레톤만 제공
- **4.1 DDL**: 노션에 명시된 경우 그대로 인용, 없으면 컬럼명/타입 **추정안** 제시 (추정에는 `(추론)` 라벨)
- **5. API 설계**: 피그마 화면 + 유사 기능 경로에서 추정한 엔드포인트 표 초안
- **6. 분기 매트릭스**: 비어있는 표 골격
- **7. 주요 설계 결정**: 최소 3개 제목 + 빈 슬롯(결정/근거/트레이드오프/**결론**)
- **9.2~9.3 알람, 배포 후 확인 절차**

### 작성 지침
- `references/skill-knowledge.md`의 "design-draft.md 작성 품질 기준 9개"를 모두 충족한다.
- 추론 내용에는 반드시 `(추론)` 라벨을 붙인다.
- 빈 슬롯은 `{...}` 또는 `{TODO: ...}`로 표시하고, 엔지니어가 무엇을 채워야 하는지 힌트를 남긴다.

---

## Phase 4 — 에이전트 팀 제안 → `agent-team.md`

`references/agent-team-guide.md`에 정의된 도메인→팀 매핑을 참조하여 추천 팀을 제안한다.

출력 형식:
- **프로젝트 특성 요약** (1~2줄)
- **권장 에이전트 팀**: 각 에이전트를 (이름, 역할, 언제 호출할지, 호출 예시 prompt) 형식으로 나열
- **추천 스킬 조합**: `plan`, `tdd`, `api-test-plan`, `monitor`, `create-pr` 등 어떤 순서로 쓰면 좋은지
- **병렬화 포인트**: 동시에 돌릴 수 있는 에이전트 조합

---

## 에러 처리

- 노션 접근 실패 (권한 등): 사용자에게 공유 권한 확인을 요청하고, 해당 Phase만 건너뛰어 나머지를 계속한다.
- 피그마 이미지 경로가 잘못되었거나 접근 실패: 사용자에게 재입력 요청.
- gongbiz-db 스킬 실패: DB 단계 스킵, `db-schema.md`에 에러 메시지 기록.
- AWS 자격증명 누락: `infra-map.md`에 "자격증명 필요: `aws configure` 또는 SSO 로그인 후 재실행"만 기록.
- 어떤 단계가 실패해도 **나머지 단계는 계속 진행**한다.

---

## 최종 출력

```
## 프로젝트 킥오프 컨텍스트 수집 완료

### 저장 위치
.claude/docs/{epic}/
├── context.md              # 얇은 개요 (네비게이션 허브)
├── design-draft.md         # 설계 문서 초안 ← 엔지니어가 이어받음
├── policy-summary.md       # 노션 정책 요약
├── design-notes.md         # 피그마 요약
├── db-schema.md            # DB 스키마
├── codebase-map.md         # 코드베이스 맵
├── infra-map.md            # AWS 인프라 맵
├── slack-notes.md          # (선택) Slack 컨텍스트
└── agent-team.md           # 에이전트 팀 제안

### 수집 요약
- 정책 페이지: {N}개
- 관련 테이블: {N}개
- 관련 코드 파일: {N}개
- 인프라 리소스: {N}개
- 건너뛴 단계: {있으면 이유와 함께}

### 추천 에이전트 팀
{agent-team.md의 상위 3개 에이전트 요약}

### 다음 단계
1. `context.md`로 전체 컨텍스트 훑어보기 (네비게이션 허브).
2. `design-draft.md`의 **[수동 검토 필요]** 섹션을 엔지니어가 채움 (Phase 분할, API 상세, 설계 결정 7개).
3. `architect` 에이전트로 초안 검토 → `critic`로 누락/리스크 재검증 (agent-team.md 참고).
4. `/plan` 또는 `/planner`로 구현 계획 수립.
5. `/api-test-plan {branch}`로 QA 플랜 준비 (구현 브랜치 생성 후).
```

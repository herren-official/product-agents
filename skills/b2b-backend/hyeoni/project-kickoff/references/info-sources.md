# 소스별 수집 방법 가이드

`/project-kickoff` 커맨드에서 각 정보원을 어떻게 수집할지 상세 지침.

---

## 1. 노션 정책 페이지

### 도구
- `mcp__claude_ai_Notion__notion-fetch` — URL/ID로 페이지 본문 읽기
- `mcp__claude_ai_Notion__notion-search` — 키워드로 페이지 검색 (추가 탐색 시)
- `mcp__claude_ai_Notion__notion-get-comments` — 코멘트 읽기 (필요 시)

### 수집 절차
1. 입력받은 URL을 `notion-fetch`로 호출한다. URL이 여러 개면 각각 호출.
2. 페이지 본문에서 다른 노션 페이지 링크를 추출한다 (`notion.so/...` 또는 `notion.site/...`).
3. 추출된 하위 링크를 **최대 1단계만** 재귀 수집한다. (무한 순환 방지)
4. 각 페이지에 대해 아래 항목을 추출:
   - 배경/목적
   - 요구사항 (기능/비기능)
   - 범위 (포함/제외)
   - 성공 지표/KPI
   - 이해관계자
   - 미결정 사항
   - 참고 링크

### 실패 처리
- 403/권한 오류: 사용자에게 공유 권한 요청 메시지 출력. 해당 URL은 스킵.
- 페이지 없음: 에러를 기록하고 계속.

---

## 2. 피그마

### 도구 (Figma 공식 MCP — OAuth 인증 완료됨)

| 툴 | 용도 |
|---|---|
| `mcp__figma__get_design_context` | 특정 노드의 디자인 코드(React+Tailwind 레퍼런스) + 스크린샷 + 힌트 일괄 수집. **최우선 도구.** |
| `mcp__figma__get_metadata` | 노드 트리/계층 구조 (프레임 개수, 레이어 이름 파악) |
| `mcp__figma__get_screenshot` | 특정 노드의 스크린샷만 |
| `mcp__figma__get_variable_defs` | 디자인 토큰 (색상, 타이포, 간격) |
| `mcp__figma__get_figjam` | FigJam 보드 (figma.com/board/...) |
| `mcp__figma__search_design_system` | 디자인 시스템 컴포넌트 검색 |
| `mcp__figma__whoami` | 인증 상태 확인 (문제 발생 시) |

### URL 파싱 규칙

| URL 형식 | 추출 |
|---|---|
| `figma.com/design/{fileKey}/{fileName}?node-id={nodeId}` | `fileKey`, `nodeId` (하이픈 `-`을 콜론 `:`으로 변환) |
| `figma.com/design/{fileKey}/branch/{branchKey}/...` | `branchKey`를 `fileKey`로 사용 |
| `figma.com/make/{makeFileKey}/...` | `makeFileKey`를 `fileKey`로 사용 |
| `figma.com/board/{fileKey}/...` | FigJam → `get_figjam` 사용 |

### 수집 절차

1. 입력받은 URL에서 `fileKey` + `nodeId` 추출.
2. **전체 파일 개요**가 필요하면 `get_metadata`로 상위 프레임 목록부터 확인.
3. 각 프레임/화면에 대해 `get_design_context` 호출 — 코드/스크린샷/힌트 한 번에.
4. 디자인 토큰이 필요하면 `get_variable_defs`.
5. FigJam 보드면 `get_figjam`.

### 추출 항목
- 화면 수와 각 화면 이름
- 주요 컴포넌트 (재사용성 판단) — Code Connect 매핑 여부 확인
- 사용자 플로우 (진입 → 완료 경로)
- 엣지 UI 상태 (데이터 없음, 에러, 로딩)
- 디자인 토큰 (프로젝트 기존 토큰과 매핑 여부)

### 이미지 파일만 있는 경우 (URL 없음)
- `Agent` 도구로 `oh-my-claudecode:vision` 에이전트 호출.
  ```
  Task(subagent_type="oh-my-claudecode:vision",
       prompt="{절대경로} 이미지를 분석하여 화면 구성, 주요 컴포넌트, 사용자 플로우, 엣지 UI 상태를 bullet로 정리하라.")
  ```

### 실패 처리
- 403/권한 오류: `whoami`로 인증 상태 확인 후 재인증 (`mcp__figma__authenticate`).
- 노드를 못 찾으면 `get_metadata`로 노드 ID 재확인.
- gongbiz 팀이 아닌 다른 조직 파일이면 사용자에게 공유 요청.

---

## 3. DB 스키마

### 도구
- `Skill` 도구로 `gongbiz-db` 스킬 호출 (READ ONLY)
- 환경은 반드시 `dev` 사용

### 수집 절차
1. 입력받은 도메인 키워드로 테이블 목록 조회.
   - 예: 키워드가 `sale`이면 `SHOW TABLES LIKE '%sale%'`
2. 각 테이블에 대해 `DESCRIBE {table}` 실행.
3. 필요 시 외래키 관계: `SHOW CREATE TABLE {table}`에서 `FOREIGN KEY` 라인만 추출.
4. 테이블 건수 파악 (대용량 여부): `SELECT COUNT(*) FROM {table}` — 10초 넘으면 생략.

### 주의
- INSERT/UPDATE/DELETE/DDL 절대 실행 금지.
- prod 환경 사용 금지 (dev만).
- 결과에 PII 컬럼은 마스킹 없이 컬럼명만 노출 (값은 노출 안 함).

---

## 4. 코드베이스 분석

### 도구
- `Agent` 도구로 `Explore` 에이전트 (thoroughness=`medium`) 호출.
- 필요 시 `oh-my-claudecode:deepsearch` 스킬 대체 사용.

### 프롬프트 예시
```
Task(subagent_type="Explore",
     prompt="'{도메인 키워드}' 관련 기존 코드를 찾아라.
     찾아야 할 것:
     1. 도메인 엔트리포인트 (Controller, Listener, Scheduler)
     2. 핵심 Service/UseCase 클래스
     3. 관련 Repository/Mapper
     4. 기존 유사 기능이 있다면 그 위치 (입력: {기존 유사 기능 경로})
     5. 재사용 가능한 DTO/Enum/Util
     각 항목은 `파일경로:라인번호` 형식으로 인용하라.
     thoroughness: medium")
```

### 추출 항목
- 엔트리포인트 (Controller/Listener/Scheduler)
- Service/UseCase 레이어
- Repository/Mapper
- 재사용 가능한 Domain/DTO/Enum
- 신규 생성이 필요한 영역 (기존에 없는 것)

---

## 5. AWS 인프라

### 사전 확인
- `aws sts get-caller-identity` 로 자격증명 확인. 실패하면 "SSO 로그인 필요" 안내.

### CloudWatch 로그 그룹
```bash
aws logs describe-log-groups \
  --log-group-name-prefix "/ecs/gongbiz-crm" \
  --query 'logGroups[].logGroupName' \
  --output text
```

### Lambda 함수
```bash
aws lambda list-functions \
  --query "Functions[?contains(FunctionName, '{keyword}')].{name:FunctionName, runtime:Runtime}" \
  --output table
```

### SQS 큐
```bash
aws sqs list-queues --queue-name-prefix "{prefix}" --output text
```

### Kafka (MSK)
```bash
aws kafka list-clusters --query 'ClusterInfoList[].{name:ClusterName, arn:ClusterArn}' --output table
```

### 추출 항목
- 로그 그룹명 + 용도 (API/Batch/Lambda 구분)
- Lambda 함수명 + 런타임
- SQS 큐명 + DLQ 유무
- Kafka 토픽명 (프로젝트에 필요하면)
- CloudWatch 알람/대시보드 이름 (관심 대상이면)

### 실패 처리
- 자격증명 없음: `infra-map.md`에 안내문만 기록하고 진행.
- 권한 부족: 해당 리소스만 스킵.

---

## 6. Slack 스레드 (선택)

### 도구
- `mcp__claude_ai_Slack__slack_read_thread` — 스레드 URL로 본문 읽기
- `mcp__claude_ai_Slack__slack_search_public_and_private` — 키워드 검색

### 수집 절차
1. 입력받은 스레드 URL 각각 `slack_read_thread`로 호출.
2. 본문에서 의사결정, 미해결 질문, 담당자 멘션을 추출.
3. 스레드 링크를 원문으로 남긴다.

### 추출 항목
- 의사결정 (무엇을 언제 누가 결정했나)
- 미해결 질문 (blocker가 될 수 있는 것)
- 담당자/관계자 Slack 핸들

---

## 7. GBIZ 에픽 번호

- 에픽 번호가 있으면 PR/커밋/브랜치 네이밍에 사용하기 위해 `context.md` 상단에 명시.
- 번호가 없으면 "미정"으로 남겨두되, `agent-team.md`에 "에픽 번호 확정 후 `/create-task`로 작업 카드 생성" 다음 단계로 명시.

---

## 수집 순서와 병렬화

- 1번(노션), 2번(피그마), 3번(DB), 4번(코드), 5번(AWS), 6번(Slack)은 **서로 독립적**이므로 병렬 실행한다.
- 단, **1번(노션) 완료 후 도메인 키워드를 추출할 수 있으므로**, 4번(코드)은 1번 완료 후 실행해도 된다 (더 정확한 탐색 가능).
  - 시간이 더 급하면 1번과 4번도 병렬로 돌리되, 4번은 사용자 입력 키워드만으로 실행.
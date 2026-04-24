---
name: b2b-android-backlog-refiner
description: 백로그 일감 정제. "일감 정제", "백로그 정제", "backlog refine", "일감 만들어줘", "노션 카드 생성", "PDF 분석해서 일감", "피그마 분석", "일감 분해", "작업 카드 생성", "슬랙 링크로 일감" 요청 시 사용
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, Agent, WebFetch, mcp__notionMCP__notion-search, mcp__notionMCP__notion-fetch, mcp__notionMCP__notion-create-pages, mcp__notionMCP__notion-update-page, mcp__notionMCP__notion-get-users, mcp__claude_ai_notion__notion-search, mcp__claude_ai_notion__notion-fetch, mcp__claude_ai_notion__notion-create-pages, mcp__claude_ai_notion__notion-update-page, mcp__claude_ai_notion__notion-get-users, mcp__Figma_Dev_Mode_MCP__get_figma_data, mcp__Figma_Dev_Mode_MCP__download_figma_images, mcp__claude_ai_Slack__slack_read_channel, mcp__claude_ai_Slack__slack_read_thread, mcp__claude_ai_Slack__slack_search_public_and_private
user-invocable: true
---

# 백로그 일감 정제 스킬

다양한 입력 소스(PDF, Figma 링크, Notion 페이지, Slack 스레드 등)를 분석하여 일감을 정제하고 Notion 백로그 카드를 생성하는 전체 워크플로를 서브 에이전트 병렬 처리로 수행한다.

## 시작 시 필요한 정보

스킬 실행 시 사용자에게 다음을 확인:

1. **에픽 정보**: 에픽명, Notion URL
2. **마일스톤 목록**: 각 마일스톤명, Notion URL
3. **인수인계서/참고 문서 경로**: 프로젝트 내 인수인계서 또는 참고 문서 파일 경로 (있는 경우)
4. **분석 대상 소스**: 아래 중 하나 이상
   - **PDF 파일**: Figma에서 추출한 PDF 파일 경로
   - **Figma 링크**: Figma 디자인 URL (MCP로 데이터 추출)
   - **Notion 링크**: 기획 문서, 요구사항 페이지 URL
   - **Slack 링크**: 논의 스레드, 채널 메시지 URL
   - **로컬 문서**: .md, .txt 등 프로젝트 내 문서
5. **기준 카드 URL**: Notion 템플릿 카드 URL (속성 구조 참고용)
6. **작업자 정보**: 기준 카드에서 작업자 user ID 추출, 또는 사용자에게 직접 확인

---

## 전체 프로세스 개요

```
Phase 0: SP 기준 분석 (단일)
    ↓ (사용자 확인)
Phase 1: 소스 분석 (서브 에이전트 병렬)
    ↓ (자동 진행)
Phase 2: 통합 문서 생성 (단일)
    ↓ (사용자 확인)
Phase 2.5: 중복/통합 검토 (단일)
    ↓ (사용자 승인)
Phase 3: 백로그 카드 생성 (서브 에이전트 병렬)
    ↓ (자동 진행)
Phase 4: 검증 (서브 에이전트 병렬, 수정 없이 보고만)
    ↓ (사용자 확인)
Phase 5: 보완 (서브 에이전트 병렬)
    ↓ (최종 보고)
완료
```

---

## Phase 0: SP 기준 분석

### 목적
사용자의 기존 Notion 완료 일감에서 SP 산정 패턴을 분석하여 기준표를 생성한다.

### 수행 내용
1. 기준 카드를 fetch하여 작업자 user ID 및 DB 구조를 파악한다
2. Notion에서 해당 작업자의 완료된 일감 중 SP가 설정된 카드를 수집한다
3. SP별 작업 규모/복잡도 패턴을 분석한다
4. SP 기준표를 생성한다 (소수점 단위)

### SP 기준표 템플릿

| SP | 작업 규모 | 예시 |
|----|----------|------|
| **0.1** | 단순 수정, 1~2개 파일 변경 | 텍스트 수정, string 변경 |
| **0.125** | 단순 변경이지만 파일이 조금 더 많음 | 메뉴명 변경, 테스트 추가 |
| **0.2** | 소규모 UI 신규 구현 | 새 UI 컴포넌트 1개 + string |
| **0.25** | 중간 규모 API 또는 UI 구현 | API Service/Repository/Entity 정의 + ViewModel 연동 |
| **0.5** | 여러 레이어에 걸친 기능 구현 | 복수 레이어 신규 기능 |
| **1.0** | 대규모 리팩토링 또는 다수 파일 수정 | 전체 레이어 수정 |

### 주의사항
- 버퍼 두지 말고 **실제 작업량 기준으로 산정**
- **사용자 확인 후** 다음 Phase 진행

---

## Phase 1: 소스 분석 (서브 에이전트 병렬)

### 목적
제공된 소스(PDF, Figma, Notion, Slack, 로컬 문서)를 병렬로 분석하여 변경 사항을 추출한다.

### 소스 유형별 분석 방법

| 소스 유형 | 도구 | 분석 방법 |
|---------|------|----------|
| **PDF 파일** | Read (pages 파라미터) | 빨간색=변경, 검정색=기존 정책 |
| **Figma 링크** | `mcp__Figma_Dev_Mode_MCP__get_figma_data` | 디자인 데이터 추출 + 변경점 분석 |
| **Notion 링크** | `mcp__notionMCP__notion-fetch` | 페이지 내용에서 요구사항 추출 |
| **Slack 링크** | `mcp__claude_ai_Slack__slack_read_thread` | 논의 내용에서 요구사항 추출 |
| **로컬 문서** | Read | 문서 내용 분석 |

### 에이전트 배정
- **소스 1개당 서브 에이전트 1개** (Agent 도구, `subagent_type: Explore`)
- 모든 에이전트를 한 메시지에서 동시 호출

### 각 에이전트 분석 내용
1. **변경 사항 추출** (소스 유형에 맞는 방법 적용)
2. **참고 문서 교차 검증** (인수인계서 등이 있는 경우)
3. **프로젝트 코드 분석** (수정 대상 파일 특정, 구현 방향)
4. **SP 산정** (Phase 0 기준표 적용)
5. **마일스톤 매핑**

### 에이전트 프롬프트 템플릿
```
다음 소스를 분석하여 백로그 일감을 정제하라.

소스: {source_path_or_url}
소스 유형: {pdf|figma|notion|slack|document}
참고 문서: {handover_path} (있는 경우)
SP 기준표: {sp_criteria}
에픽/마일스톤 정보: {epic_info}
프로젝트 경로: {project_root}

분석 규칙:
1. 변경/추가 사항 추출 (소스 유형에 맞는 방법)
2. 참고 문서와 교차 검증 (있는 경우)
3. 프로젝트 코드에서 수정 대상 파일 탐색
4. SP 산정 (기준표 적용, 버퍼 없음)
5. 마일스톤 매핑

출력 형식: (일감별)
### 일감 N: [CRM][Android] {정제 내용}
- **마일스톤**: {매핑 결과}
- **변경 유형**: 신규/수정/구조 변경
- **변경 사항**: (원문 기반, 요약/변경 금지)
- **기존 정책**: (현재 동작)
- **구현 가이드**:
  - 수정 대상 파일: {파일 경로}
  - 구현 방향: {어떻게 수정할지}
- **SP**: {소수점}
- **SP 근거**: {왜 이 SP인지}
```

### Phase 전환
- 모든 서브 에이전트 결과 반환 시 **자동으로 Phase 2 진행**

---

## Phase 2: 통합 문서 생성

### 목적
모든 PDF 분석 결과를 하나의 .md 파일로 통합한다.

### 산출물
`.docs/local/plans/{프로젝트명}-backlog-items.md`

### 문서 구조
```markdown
# {프로젝트명} - 백로그 일감 정제 결과

> 작성일: {날짜}
> 총 N개 일감 / 총 SP: X.XX

## 마일스톤 1: {마일스톤명} (N개 / SP X.XX)
### {화면/기능 카테고리} (N개)
#### 일감 N: [CRM][Android] {정제 내용}
- **변경 유형**: 신규/수정/구조 변경
- **변경 사항**: (상세 내용)
- **기존 정책**: (기존 동작)
- **구현 가이드**: 수정 대상 + 구현 방향
- **SP**: X.X / **SP 근거**: (산정 이유)

## 총 요약
## API 의존성 정리
## 바로 시작 가능 (API 불필요)
```

### Phase 전환
- **사용자 확인 후** Phase 2.5 진행

---

## Phase 2.5: 중복/통합 검토

### 통합 대상
- SP 0.1 이하 일감이 같은 마일스톤 내에 여러 개
- 같은 파일/함수를 수정하는 일감
- 하나의 플로우에 속하는 일감

### 통합 금지
- **마일스톤 간 통합 금지**
- **SP 0.5 이상 일감끼리 통합 금지**
- **독립적 기능 통합 금지**

### 추가 확인
- API 일감 누락 여부 (Service/Repository/Entity)
- 테스트 일감 누락 여부

### Phase 전환
- **사용자 승인 후** Phase 3 진행

---

## Phase 3: 백로그 카드 생성 (서브 에이전트 병렬)

### 에이전트 배정
- **마일스톤 단위로 서브 에이전트 배정** (`subagent_type: general-purpose`, `mode: auto`)

### Notion 카드 속성

| 속성 | 값 |
|------|-----|
| **제목** | `[CRM][Android] {정제 내용}` |
| **에픽** | 사용자가 지정한 에픽 URL |
| **마일스톤** | 매핑된 마일스톤 URL |
| **서비스** | 공비서-B2B |
| **플랫폼** | Android |
| **작업자** | 사용자 Notion user ID |
| **유형** | 작업 |
| **상태** | 백로그 |
| **스토리포인트** | 소수점 단위 |

### 카드 본문 템플릿
```markdown
## **작업내용** {color="blue_bg"}
### 내용
<callout icon="💡" color="gray_bg">
  작업 상세 내용
</callout>
- {변경 사항 상세}
- {구현 가이드}

### 참고
<callout icon="💡" color="gray_bg">
  관련 리소스 링크
</callout>
- 피그마: {피그마 링크}
- 인수인계서: {인수인계서 참조}

---
### Todo
- [ ] {세부 작업 1}
- [ ] {세부 작업 2}
```

### Phase 전환
- 모든 서브 에이전트 결과 반환 시 **자동으로 Phase 4 진행**

---

## Phase 4: 검증 (서브 에이전트 병렬)

### 목적
생성된 Notion 카드를 검증한다. **수정하지 않고 결과만 보고한다.**

### 에이전트 배정
- 마일스톤별 서브 에이전트 (`subagent_type: Explore`)

### 검증 항목
- 속성 완결성 / 제목 형식 / 내용 완결성 / 중복 / 누락 / SP 적절성 / 인수인계서 대조

### Phase 전환
- **사용자 확인 후** Phase 5 진행

---

## Phase 5: 보완 (서브 에이전트 병렬)

### 수행 내용
1. 검증 이슈 수정 (`notion-update-page`)
2. 인수인계서 최종 교차 검증
3. 최종 보고

### 에이전트 배정
- 마일스톤별 서브 에이전트 (`subagent_type: general-purpose`, `mode: auto`)

---

## Phase 전환 조건 요약

| Phase | 다음 | 전환 방식 |
|-------|------|----------|
| 0 → 1 | SP 기준표 | **사용자 확인** |
| 1 → 2 | PDF 분석 완료 | **자동 진행** |
| 2 → 2.5 | 통합 문서 | **사용자 확인** |
| 2.5 → 3 | 통합 결과 | **사용자 승인** |
| 3 → 4 | 카드 생성 완료 | **자동 진행** |
| 4 → 5 | 검증 결과 | **사용자 확인** |
| 5 → 완료 | 보완 완료 | **최종 보고** |

---

## 핵심 규칙

### ⛔ 금지
- Phase 4에서 Notion 카드를 직접 수정하지 않는다 (결과만 보고)
- 마일스톤 간 일감을 통합하지 않는다
- SP 0.5 이상 일감끼리 통합하지 않는다
- 모달/토스트 문구를 요약하거나 변경하지 않는다 (피그마 원본 그대로)
- SP에 버퍼를 두지 않는다 (실제 작업량 기준)
- 사용자 승인 없이 Phase 3(카드 생성)을 진행하지 않는다
- 카드 삭제는 사용자 승인 없이 하지 않는다

### ✅ 필수
- PDF 분석 시 빨간색/검정색 글씨를 반드시 구분한다
- 인수인계서와 교차 검증한다
- 프로젝트 코드를 실제 분석하여 수정 대상 파일을 특정한다
- SP 기준표를 적용하여 일관된 SP를 산정한다
- 카드 제목은 `[CRM][Android] {정제 내용}` 형식
- API 의존성을 정리하여 "바로 시작 가능" vs "API 대기" 구분한다

## 상세 규칙 참조

- Notion 카드 컨벤션: [notion-card-convention.md](../../.docs/local/notion-card-convention.md)
- Notion API 가이드: [notion-api-cli-guide.md](../../.docs/local/notion-api-cli-guide.md)

---
name: b2b-backend-figma-collector
description: Figma URL을 받아 구조화된 디자인 컨텍스트(섹션 트리 + 스펙 텍스트)를 생성하는 수집 스킬. 오케스트레이터(spec-orchestrator)의 Phase 0에서 호출된다.
---

# Figma 디자인 수집 (figma-collector)

## 역할

Figma 디자인 URL을 입력받아, 페이지/섹션 구조와 스펙 텍스트를 추출하여 구조화된 markdown 파일로 저장한다.

## 입력

- **Figma URL**: `https://www.figma.com/design/...?node-id=XXXX-YYYY` 형태
- **저장 경로**: 절대 경로

## 출력

- `{저장경로}/figma_context.md` — 구조화된 디자인 컨텍스트

## 핵심 원칙

1. **큰 틀 → 세부**: 페이지 → 섹션 → 프레임 → 개별 노드 순서로 점진 접근
2. **텍스트는 개별 노드 단위로**: New-Summary 전체가 아닌 Summary-Content 개별 노드로 추출
3. **폴백 체인**: get_design_context(정확) → get_screenshot(개별 노드, 선명 OCR) → get_screenshot(상위 노드, 마지막 수단)
4. **OCR 검증**: 의미 불명 텍스트 감지 시 해당 영역을 하위 노드로 재수집

## MCP 도구 특성

| 도구 | 장점 | 단점 | 용도 |
|------|------|------|------|
| `get_metadata` | 빠름, 구조 파악에 적합 | 노드 name만 제공, 실제 텍스트(characters) 없음 | Step 2-3: 구조 파악 + 스펙 노드 식별 |
| `get_design_context` | 실제 텍스트 포함, 가장 정확 | 큰 노드는 타임아웃 위험 | Step 5-1차: 개별 노드 텍스트 추출 |
| `get_screenshot` | 항상 작동, 시각적 확인 | OCR 의존, 작은 글씨 부정확 | Step 4: 화면 확인, Step 5-2차: 폴백 |

## 워크플로우

### Step 1: URL 파싱

1. URL에서 node-id 추출
2. `node-id=1954-42095` → nodeId `1954:42095`로 변환 (`-` → `:`)
3. branch URL인 경우 (`/branch/:branchKey/`) branchKey를 fileKey로 사용
4. node-id가 없으면 Step 2에서 페이지 탐색 필수

### Step 2: 페이지 탐색

> **목적**: 올바른 페이지를 먼저 찾는다. 잘못된 페이지에서 시작하면 스펙 노드를 못 찾고 헤맨다.

1. `get_metadata(nodeId="0:1")`로 전체 페이지(canvas) 목록 파악
   - 결과가 초대형이면 서브에이전트로 파싱 위임
   - Python으로 `<canvas id="..." name="...">` 추출

2. 페이지 선택:
   - URL에 node-id 있으면 → 해당 nodeId가 속한 페이지 사용
   - node-id 없으면 → 페이지 이름 목록을 사용자에게 보여주고 선택 요청
   - 페이지가 1개뿐이면 → 해당 페이지 자동 선택

3. 선택된 페이지 ID 기록 (이후 모든 작업의 기준점)

#### 주의: HTML entity 변환

metadata 결과에 `&gt;` (→ `>`), `&lt;` (→ `<`) 등 HTML entity가 포함되어 있다.
**파싱 전에 반드시 entity를 변환**해야 정확한 필터링이 가능하다.

```python
content = content.replace('&gt;', '>').replace('&lt;', '<').replace('&amp;', '&')
```

### Step 3: 구조 파악 (metadata 기반)

> **목적**: 섹션/프레임 트리 + 스펙 노드 위치를 파악한다.

1. 선택된 페이지에 `get_metadata` 호출
   - 결과가 초대형이면 서브에이전트로 파싱 위임

2. **섹션/프레임 트리 추출** (Python 파싱):
   ```python
   # section, frame 태그에서 id, name 추출
   pattern = r'<(?:section|frame)\s+id="(\d+:\d+)"\s+name="([^"]*)"'
   ```

3. **스펙 노드 전수 식별** — 다음 이름 패턴의 노드를 전수 검색:
   | 우선순위 | 노드 이름 | 역할 |
   |:-------:|----------|------|
   | 1 | `Summary-Content` | 스펙 본문 (개별 항목) — **텍스트 추출의 핵심 단위** |
   | 2 | `Summary-Title` | 스펙 제목 |
   | 3 | `New-Summary` | 스펙 그룹 (Summary-Title + Summary-Content N개의 부모) |
   | 4 | `View Section` | 스펙이 속한 화면 프레임 |
   | 5 | `Annotation Spec` | 주석/설명 (보통 작은 텍스트) |
   | 6 | 이름에 `spec`, `정의`, `정책`, `변수`, `규칙` 포함 | 기타 스펙 노드 |

4. **스펙 노드 그룹핑**:
   - New-Summary를 기준으로 하위 Summary-Content 매핑
   - 각 New-Summary가 어떤 View Section(화면)에 속하는지 매핑
   - 결과를 `/tmp/figma_spec_nodes.md`에 저장:
     ```
     # 스펙 노드 맵
     ## View Section: [2191:43972] (메시지 내용 : 카카오톡 근처)
     - New-Summary: [2191:44108]
       - Summary-Title: [2191:44109]
       - Summary-Content: [2191:44110] ← 개별 수집 대상
       - Summary-Content: [2191:44111] ← 개별 수집 대상
       ...
     ```

### Step 4: 핵심 화면 스크린샷 수집

> **목적**: 전체 UI 레이아웃을 시각적으로 확인한다. 스펙 텍스트 추출용이 아님.

1. Step 3에서 식별된 주요 화면 프레임(최대 5개) 선별:
   - "주요 화면" 이름 포함 → 최우선
   - `[Section]` 태그가 붙은 프레임 → 우선
   - `[Modal]`, `[Flow]` → 후순위
   - 중복 제거 후 상위 5개

2. 각 화면에 `get_screenshot` 호출
3. 확인한 내용을 figma_context.md의 해당 화면 섹션에 텍스트로 기록:
   - 주요 UI 요소 (버튼, 입력필드, 테이블 등)
   - 화면 레이아웃 설명 (1~2줄)

**이 단계는 레이아웃 확인용이다. 스펙 텍스트는 Step 5에서 추출한다.**

### Step 5: 스펙 텍스트 추출 (폴백 체인, 핵심)

> **핵심**: 피그마에 명시된 정책/정의/규칙은 곧 확정 정책이다.
> 변수 정의, 치환 규칙, 동작 정의, 제약 조건 등이 피그마 스펙에 있으면
> 이후 에이전트가 "미정의"로 판단하여 QnA에 올리는 오류를 방지한다.
> **이 단계를 생략하면 설계/구현에서 정책 불일치가 반드시 발생한다.**

#### 추출 단위: Summary-Content 개별 노드

**New-Summary 전체를 한 번에 잡지 않는다.** 하위 Summary-Content를 개별로 추출한다.
- New-Summary 전체 스크린샷 → 텍스트가 작아서 OCR 부정확
- Summary-Content 개별 스크린샷 → 텍스트가 크고 선명

#### 폴백 체인 (1차 → 2차 → 3차)

```
1차: get_design_context(Summary-Content 개별 nodeId)
     → 성공: 텍스트 정확 추출, 기록
     → 실패(타임아웃): 2차로

2차: get_screenshot(Summary-Content 개별 nodeId)
     → 성공: 선명한 OCR, 기록
     → OCR 검증: 의미 불명 텍스트 감지 시 3차로
     → 실패: 3차로

3차: get_screenshot(New-Summary 전체 nodeId)
     → 마지막 수단. 전체 스펙 문서를 한 장으로 캡처
     → OCR 부정확 가능성 있음을 명시
```

#### OCR 검증 기준

다음 패턴이 보이면 해당 영역을 하위 노드로 재수집:
- 한글이 아닌 의미 불명 문자열 (예: "미처리(전달처 상태의 전달대로 조직)됨")
- 문장이 중간에 끊긴 것 (예: "조건적 정수)")
- 동일 단어가 연속 반복 (예: "Selected Selected Selected")

재수집 시:
1. 해당 New-Summary의 Summary-Content 목록에서 문제 영역 특정
2. 해당 Summary-Content에 get_screenshot 개별 호출 (확대 효과)

#### 추출 시 반드시 확인할 항목

- [ ] 변수 정의: 변수명, 치환값, 조건 (예: "펫 이름: 고객에게 등록된 1번째 펫 이름")
- [ ] 동작 규칙: Default 상태, 활성화 조건, 클릭 동작
- [ ] 타입/분류: SMS/LMS/MMS 구분 기준, byte 기준
- [ ] 제약 조건: 최대 길이, 이모지 제한, 시간 제한 등
- [ ] UI 상태: 활성/비활성 조건, 에러 상태
- [ ] 야간 제한: 정확한 시간 범위 (예: 오전 8:00 ~ 오후 8:40)
- [ ] 차감 규칙: 건당 차감 개수, 선차감/후차감 정책

→ 하나라도 있으면 전문 기록. **요약하지 않고 원문 그대로 기록.**

### Step 6: markdown 구조화

```markdown
# 피그마 디자인 컨텍스트

> 수집일: YYYY-MM-DD
> URL: {원본 URL}
> 페이지: {페이지명} (node-id: {pageId})

## 캔버스
- [{node-id}] {캔버스명}

## 핵심 화면

| # | 화면 | Node ID | 설명 |
|---|------|---------|------|
| 1 | {화면명} | {node-id} | {1줄 설명} |

## 스펙 텍스트 (정책/변수/규칙 원문)

> 피그마 스펙 노드에서 추출한 원문. 요약하지 않음.
> 이 섹션의 내용은 확정 정책으로 취급한다.

### {섹션명} (node-id: {id})

update: {날짜} | designer: {이름}

{스펙 원문 전체}
```

### Step 7: 저장 + 검증

1. Write 도구로 `{저장경로}/figma_context.md`에 저장
2. 검증:
   - 섹션 수가 0이면 경고 → pageId 재확인
   - 스펙 텍스트 섹션이 0이면 경고 → 스펙 노드 재탐색
   - 의미 불명 텍스트 없는지 전수 확인
   - `##` heading 존재 확인
   - 파일 크기 확인

## 에러 처리

| 상황 | 대응 |
|------|------|
| Figma Desktop 미실행 | `get_metadata` 실패 → URL만 기록하고 경고 |
| node-id 없음 | Step 2에서 페이지 목록 → 사용자 선택 |
| 잘못된 페이지 접근 | 스펙 노드 0개 → 다른 페이지에서 재탐색 |
| get_design_context 타임아웃 | 폴백 체인 2차(get_screenshot 개별 노드)로 전환 |
| get_screenshot OCR 부정확 | 의미 불명 텍스트 감지 → 하위 노드로 재수집 |
| metadata 결과 초대형 | 서브에이전트로 파싱 위임 (/tmp/ 파일 저장 후 처리) |
| 스펙 노드 0개 | 다른 페이지 탐색, 또는 프레임 이름 키워드 검색 확대 |

## 제한사항

- Figma Desktop 앱이 실행 중이어야 MCP 도구가 동작한다
- 스크린샷은 에이전트 컨텍스트 내에서만 시각적으로 확인 가능 (파일 저장 불가)
- 대형 캔버스(섹션 100개+)에서는 핵심 10개만 선별하여 컨텍스트 절약
- get_design_context는 큰 노드에서 타임아웃 빈발 → Summary-Content 개별 단위로 호출
- metadata의 text 노드 name은 레이블만 포함, 실제 스펙 본문은 get_design_context 또는 스크린샷 필요

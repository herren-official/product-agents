---
name: crm-ios-figma-analyze
description: 피그마 URL을 받아 UI 분석과 정책 분석을 병렬로 수행합니다. 피그마, figma, 디자인 분석 요청 시 사용.
user_invocable: true
---

# Figma Analyze

피그마 URL을 받아 **노드 분리 → 병렬 분석 → 결과 종합**을 수행하는 스킬입니다.

## 실행 프로세스

### Step 1: 피그마 URL 확인
사용자로부터 피그마 URL을 확인합니다.
- URL이 없으면 요청
- 여러 URL(섹션별)이 있으면 모두 수집
- 각 URL에 이름/설명이 있으면 함께 기록

### Step 1.5: 노드 분리 (자동)
URL이 1개인 경우, `get_metadata`로 하위 섹션 노드를 자동 탐색합니다.

1. **`get_metadata`** 호출하여 상위 노드의 하위 구조 파악
2. **모든** 하위 노드(section/frame/instance)를 빠짐없이 추출
3. 각 노드의 `name`과 `id`를 정리

```
예시: 고객 통계 (12691:23029)
  ├─ 주요 화면 (12691:23030)
  ├─ Section-고객 통계 네비게이션(헤더) (12691:23427)
  │   ├─ 일별 (12691:29198)
  │   ├─ 주별 (12691:25788)
  │   ├─ 월별 (12691:25797)
  │   └─ 퀵버튼 활성화 (12691:29422)
  ├─ Section-고객 통계 데이터 영역 (12705:15225)
  │   ├─ 조회 기간 데이터 : 일별 (12705:16112)
  │   └─ Summary 스펙 (12691:25645)
  └─ 2-2 툴팁 모달 (12688:17130)    ← 모달/팝업도 반드시 포함
```

4. **전체** 노드 목록을 사용자에게 보고하고 확인 후 진행
   - 너무 큰 노드(전체 페이지)는 하위로 분리
   - **임의로 노드를 제외하지 말 것** — 모달, 팝업, 토스트, 에러 상태 등 부속 UI도 모두 포함
   - 사용자가 명시적으로 제외를 요청한 노드만 제외

> **주의**: `get_metadata`가 타임아웃되면 사용자에게 즉시 보고하고 하위 노드 URL을 직접 요청

> **주의**: `get_design_context`가 타임아웃되면 동일 노드로 재시도하지 말고, 더 작은 하위 노드로 분리하여 시도

### Step 2: 병렬 분석 실행
Agent 도구를 사용하여 **각 노드마다 UI + 정책 에이전트를 동시에** 실행합니다.

#### 분리된 노드별 병렬 호출
각 노드마다 UI + 정책 에이전트를 모두 병렬 호출:
```
예시: 3개 노드 → 6개 Agent를 하나의 메시지에서 동시 실행

Agent 1: crm-ios-figma-ui-analyzer (일별 노드)
Agent 2: crm-ios-figma-policy-analyzer (일별 노드)
Agent 3: crm-ios-figma-ui-analyzer (주별 노드)
Agent 4: crm-ios-figma-policy-analyzer (주별 노드)
Agent 5: crm-ios-figma-ui-analyzer (월별 노드)
Agent 6: crm-ios-figma-policy-analyzer (월별 노드)
```

**중요**: 반드시 모든 Agent를 **하나의 메시지에서** 병렬로 호출하세요.

에이전트 정의 파일을 먼저 읽고, 각 에이전트 프롬프트에 해당 에이전트의 분석 프로세스와 출력 형식을 포함하세요.

### Step 2.5: 컴포넌트 매핑
Step 2의 UI 분석 결과가 완료되면, **crm-ios-component-mapper** 에이전트를 실행합니다.

전달 정보:
- Step 2의 crm-ios-figma-ui-analyzer 결과 (전체 종합)
- 참고 코드 경로 (사용자가 제공한 경우)
- 작업 대상 (UIKit / SwiftUI)

```
Agent: crm-ios-component-mapper
- 입력: UI 분석 결과 + 참고 코드 경로
- 출력: 피그마 → 프로젝트 컴포넌트 매핑 테이블 + 문구 확인 결과
```

### Step 3: 결과 종합
모든 에이전트의 결과를 노드별로 종합하여 사용자에게 보고합니다:

```
## 피그마 분석 결과

### 노드 1: {노드 이름} (node-id: {id})

#### UI 분석
{crm-ios-figma-ui-analyzer 결과}

#### 정책 분석
{crm-ios-figma-policy-analyzer 결과}

---

### 노드 2: {노드 이름} (node-id: {id})

#### UI 분석
{crm-ios-figma-ui-analyzer 결과}

#### 정책 분석
{crm-ios-figma-policy-analyzer 결과}

### 컴포넌트 매핑
{crm-ios-component-mapper 결과}
```

## 사용 예시

### URL 1개 (자동 노드 분리)
```
/crm-ios-figma-analyze
https://www.figma.com/design/...?node-id=12691-23029
```
→ get_metadata로 하위 섹션 자동 탐색 → 노드별 병렬 분석

### URL 여러 개 (수동 섹션 지정)
```
/crm-ios-figma-analyze
1. 고객 등록 화면: https://www.figma.com/design/...?node-id=13482-115356
2. 소개자 검색 화면: https://www.figma.com/design/...?node-id=xxxx-xxxxx
3. Summary 스펙: https://www.figma.com/design/...?node-id=xxxx-xxxxx
```
→ 각 URL에 대해 바로 병렬 분석 (Step 1.5 생략)

## 에이전트 PID 추적

에이전트를 spawn할 때마다 PID를 추적하여 좀비 프로세스를 방지합니다.

**에이전트 spawn 전:**
```bash
ps aux | grep claude | grep -v grep | awk '{print $2}' | sort > /tmp/claude-pids-before.txt
```

**에이전트 spawn 후:**
```bash
ps aux | grep claude | grep -v grep | awk '{print $2}' | sort > /tmp/claude-pids-after.txt
comm -13 /tmp/claude-pids-before.txt /tmp/claude-pids-after.txt >> /tmp/claude-agent-pids.txt
```

**모든 분석 완료 후 정리:**
```bash
while read pid; do
  if ps -p "$pid" > /dev/null 2>&1; then
    echo "좀비 에이전트: PID $pid"
  fi
done < /tmp/claude-agent-pids.txt
```

좀비가 있으면 추적된 PID만 종료한다.
```bash
while read pid; do
  if ps -p "$pid" > /dev/null 2>&1; then
    kill "$pid" 2>/dev/null
  fi
done < /tmp/claude-agent-pids.txt
rm -f /tmp/claude-agent-pids.txt /tmp/claude-pids-before.txt /tmp/claude-pids-after.txt
```

**⚠️ 추적된 PID만 종료 가능. 추적되지 않은 Claude 프로세스는 절대 종료 금지.**

## 에이전트 파일 참조
분석 실행 전 반드시 다음 에이전트 정의를 읽어서 프롬프트에 반영하세요:
- `.claude/agents/figma-ui-analyzer.md`
- `.claude/agents/figma-policy-analyzer.md`
- `.claude/agents/component-mapper.md`

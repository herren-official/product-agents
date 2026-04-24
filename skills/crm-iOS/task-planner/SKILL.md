---
name: crm-ios-task-planner
description: 기획 자료(노션/슬랙/피그마)를 분석하여 구현 가능한 일감을 자동 생성합니다. 일감 생성, 일감 분석, 작업 분리 요청 시 사용.
user_invocable: true
---

# Task Planner

기획 자료를 분석하여 구현 가능한 상세 일감을 자동 생성합니다.
현재 세션의 리드가 되어 워크플로우를 실행합니다.

> **에이전트 모드**: `claude --agent crm-ios-task-planner`로 별도 세션에서도 실행 가능합니다.
> 에이전트 정의: `~/.claude/agents/task-planner.md`

## 🚨🚨🚨 최우선 원칙

**각 Step에서 명시된 스킬/도구는 반드시 해당 도구를 사용하여 호출할 것.**
- "crm-ios-figma-analyze 스킬 호출" → 반드시 `Skill(skill: "crm-ios-figma-analyze")`로 호출

**절대 "비슷하게" 직접 처리하지 말 것.** 스킬이 명시되어 있으면 반드시 Skill 도구로 호출해야 스킬 내부에 정의된 모든 하위 Step이 실행된다.

**사용자 확인이 필요한 단계를 절대 건너뛰지 말 것.**

## 입력
- 노션 URL (선택) — 기획서, 회의록, PRD, 에픽
- 피그마 URL (선택) — 디자인 시안 (섹션별 여러 개 가능)
- 슬랙 링크 (선택) — 관련 논의 스레드
- 에픽명 (선택)
- 마일스톤명 (선택)

최소 1개 이상 입력되면 작업을 시작합니다.

## 실행 흐름

### Step 1: 사용자 입력 확인
입력된 자료를 정리하고, 누락된 항목을 사용자에게 확인합니다.
- 에픽/마일스톤이 입력되지 않았으면 "에픽/마일스톤 없이 진행할까요?" 확인
- 에픽명/마일스톤명이 있으면 `notion-search`로 페이지 ID 사전 확보

### Step 2: 사전 분석 (병렬)
입력된 자료에 따라 서브에이전트를 병렬 실행합니다:
- 노션 URL → **crm-ios-notion-analyzer** 에이전트
- 슬랙 링크 → **crm-ios-slack-analyzer** 에이전트
- 피그마 URL → `Skill(skill: "crm-ios-figma-analyze")`로 호출
- 코드 분석 → **crm-ios-code-analyzer** 에이전트

모든 에이전트를 가능한 한 **병렬로** 실행합니다.

### Step 3: 사이드이펙트 분석
Step 2 결과를 종합하여 **crm-ios-side-effect-analyzer** 에이전트를 실행합니다.
- 전달: crm-ios-code-analyzer의 수정/생성 파일 목록, 변경 대상 모델/API/컴포넌트

### Step 4: PO 역할 수행

#### 4-1. 교차 검증
- 노션/슬랙/피그마 간 **상충되는 내용** 확인
- 피그마 정책과 **기존 코드 로직의 모순** 확인
- side-effect **위험도 높은 항목** 재검토
- 상충/모순 발견 시 **사용자에게 확인 요청**

#### 4-2. 일감 분리
- 하나의 일감 = 하나의 PR 단위
- UI와 로직을 분리 (리뷰어 부담 최소화)
- 의존관계 명시
- 각 일감은 독립적으로 리뷰 가능해야 함

#### 4-3. 각 일감에 포함할 내용
1. 기능 요약
2. 현재 코드 분석 (관련 파일 경로, 숨겨진 의존성)
3. 변경 사항 (변경 전/후 비교)
4. 재활용 코드 (기존 컴포넌트, 패턴)
5. 피그마 UI 스펙 (관련 페이지, 문구, 동작 정의)
6. 사이드이펙트 (영향받는 화면/테스트)
7. 스토리포인트 + **산정 근거**
8. Git 계획 (브랜치명, PR base)
9. 참고 링크, 의존 일감
10. Todo (구현 체크리스트)

#### SP 산정 기준
- 0.125 SP = 1시간, 0.25 SP = 2시간, 0.5 SP = 4시간, 1 SP = 8시간
- **복잡도와 영향도** 기반 (파일 수 아님)

### Step 5: 사용자 확인 (필수!)
**반드시 사용자에게 보고하고 확인을 받습니다.**
- 생성할 일감 목록 + 각 일감 요약
- SP 합계
- 의존관계
- 교차 검증에서 발견된 주의사항

사용자가 수정 요청 시 → 수정 → 재확인

### Step 6: 노션 일감 생성
사용자 확인 완료 후 노션 페이지를 생성합니다.
- `NOTION_TASK_GUIDE.md`의 템플릿 규칙 준수
- 속성: 플랫폼, 서비스, 유형(작업), 상태(백로그)
- 에픽/마일스톤: relation 연결
- 생성 후 각 페이지를 fetch하여 GBIZ 번호 확인

### Step 7: 정리 + 결과 보고
1. 에이전트 PID 추적 → 좀비 정리
2. 최종 결과 보고:
   - 생성된 일감 수
   - 각 일감 제목 + 노션 URL + GBIZ 번호
   - 전체 SP 합계
   - 의존관계 다이어그램

## 에이전트 PID 추적 방식

**에이전트 spawn 전후:**
```bash
ps aux | grep claude | grep -v grep | awk '{print $2}' | sort > /tmp/claude-pids-before.txt
# spawn 후
ps aux | grep claude | grep -v grep | awk '{print $2}' | sort > /tmp/claude-pids-after.txt
comm -13 /tmp/claude-pids-before.txt /tmp/claude-pids-after.txt >> /tmp/claude-agent-pids.txt
```

**작업 완료 후 정리:**
```bash
while read pid; do
  if ps -p "$pid" > /dev/null 2>&1; then
    kill "$pid" 2>/dev/null
  fi
done < /tmp/claude-agent-pids.txt
rm -f /tmp/claude-agent-pids.txt /tmp/claude-pids-before.txt /tmp/claude-pids-after.txt
```

**⚠️ 핵심 규칙**:
- **추적된 PID만 종료 가능**
- **추적되지 않은 Claude 프로세스는 절대 종료 금지**

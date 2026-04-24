---
name: crm-ios-task-executor
description: 노션 일감 URL을 받아 사전 분석 → 구현 → 검증 → 커밋/PR까지 전체 작업을 실행합니다. 워크플로우, 일감 실행, 작업 진행 요청 시 사용.
user_invocable: true
---

# Task Executor

노션 일감 URL을 받아 전체 작업 흐름을 관리합니다.
현재 세션의 리드가 되어 워크플로우를 실행합니다.

> **에이전트 모드**: `claude --agent crm-ios-task-executor`로 별도 세션에서도 실행 가능합니다.
> 에이전트 정의: `~/.claude/agents/task-executor.md`

## 🚨🚨🚨 최우선 원칙

**각 Step에서 명시된 스킬/도구는 반드시 해당 도구를 사용하여 호출할 것.**
- "crm-ios-figma-analyze 스킬 호출" → 반드시 `Skill(skill: "crm-ios-figma-analyze")`로 호출
- "crm-ios-commit 스킬 호출" → 반드시 `Skill(skill: "crm-ios-commit")`로 호출
- "crm-ios-pr 스킬 호출" → 반드시 `Skill(skill: "crm-ios-pr")`로 호출
- "crm-ios-branch-creator 스킬 호출" → 반드시 `Skill(skill: "crm-ios-branch-creator")`로 호출

**절대 "비슷하게" 직접 처리하지 말 것.** 스킬이 명시되어 있으면 반드시 Skill 도구로 호출해야 스킬 내부에 정의된 모든 하위 Step이 실행된다.

## 입력
- 노션 일감 URL (필수)
- 피그마 URL (선택)
- 슬랙 링크 (선택)
- 참고 코드/화면 (선택)

## 실행 흐름

### Step 1: 일감 읽기
노션 일감 URL을 fetch하여 다음 정보를 추출:
- 작업 내용 (기능 요약, 변경 사항)
- Todo 체크리스트
- 참고 링크 (피그마, 슬랙, 노션 등)
- Git 계획 (브랜치명, 커밋 메시지, PR 정보)
- 에픽, GBIZ 번호

### Step 2: 사전 분석 (병렬)
일감에 포함된 참고 링크에 따라 분석을 실행:
- 피그마 링크 → `Skill(skill: "crm-ios-figma-analyze")`로 호출 (노드 분리 → UI/정책 분석 → 컴포넌트 매핑)
- 코드 파일 명시 → **crm-ios-code-analyzer** 에이전트 (해당 파일을 직접 읽고 현재 코드 이해)
- 슬랙 링크 → **crm-ios-slack-analyzer** 에이전트 (추가 맥락 확인)
- 추가 노션 링크 → **crm-ios-notion-analyzer** 에이전트

참고 코드가 있으면 에이전트 요약에 의존하지 말고 **원본 파일을 직접 Read로 읽을 것**.

### Step 3: 사전 준비

#### 3-1. 문서 확인
`Skill(skill: "crm-ios-document-checker")`로 호출: 작업 유형에 맞는 필수 문서 확인

#### 3-2. 브랜치 생성 + 노션 업데이트
`Skill(skill: "crm-ios-branch-creator")`로 호출: 아래 3가지를 한 번에 처리
- 브랜치 생성 (네이밍 규칙에 맞게)
- 노션 상태 → "작업 중" 변경
- 스프린트 설정

> **⚠️ 주의**: `git checkout -b`로 직접 브랜치를 생성하지 말 것. 반드시 `Skill(skill: "crm-ios-branch-creator")`를 통해 생성해야 노션 상태/스프린트 업데이트가 누락되지 않음.

### Step 4: 구현
전달 정보를 기반으로 코드를 구현:
- Step 1의 일감 내용 (기능 요약, 변경 사항, Todo)
- Step 2의 사전 분석 결과 (피그마 세부 스펙, 컴포넌트 매핑, 현재 코드 상태)
- Step 3의 문서 확인 결과 (컨벤션, 패턴)

> **⚠️ UI 작업 시**: 피그마에 없는 문구를 임의로 만들지 말 것. crm-ios-component-mapper 결과의 컴포넌트/문구를 그대로 사용할 것.

### Step 5: 검증 (병렬)
구현 완료 후 다음을 동시에 실행:
- **crm-ios-build-checker**: 앱 빌드(컴파일) 확인
- **crm-ios-test-writer**: 테스트 코드 작성 + 실행
- **crm-ios-side-effect-verifier**: 구현 후 사이드이펙트 실제 검증
- **convention-checker**: `Skill(skill: "crm-ios-pre-commit-checker")`로 호출
- **crm-ios-implementation-verifier**: 피그마 스펙/요구사항/Todo 일치 검증

검증 결과에 에러가 있으면 수정 후 재검증.

### Step 6: simplify (코드 리뷰)
`Skill(skill: "simplify")`로 호출하여 코드 재사용, 품질, 효율성을 검토합니다.

### Step 7: 작업 내용 보고 (사용자 확인)
**반드시 사용자에게 보고하고 확인을 받습니다.**
- 변경된 파일 목록 + git diff
- 구현 상세 (UI 구조, 로직 흐름)
- 검증 결과
- 사용자가 수정 요청 시 → 수정 → 재검증

### Step 8: 커밋 + PR
**사용자 확인 완료 후 진행합니다.**
1. 커밋: `Skill(skill: "crm-ios-commit")`로 호출
2. PR: `Skill(skill: "crm-ios-pr")`로 호출

### Step 9: 정리
팀/에이전트를 사용한 경우 반드시 정리.

#### 에이전트 PID 추적 방식

**에이전트 spawn 직후:**
```bash
# 에이전트 spawn 전 스냅샷
ps aux | grep claude | grep -v grep | awk '{print $2}' > /tmp/claude-pids-before.txt

# 에이전트 spawn 후 스냅샷
ps aux | grep claude | grep -v grep | awk '{print $2}' > /tmp/claude-pids-after.txt

# 새로 생긴 PID 기록
comm -13 /tmp/claude-pids-before.txt /tmp/claude-pids-after.txt >> /tmp/claude-agent-pids.txt
```

**에이전트 작업 완료 후 정리:**
```bash
# 추적된 에이전트 PID 중 아직 살아있는 것 확인
while read pid; do
  if ps -p "$pid" > /dev/null 2>&1; then
    echo "좀비 에이전트: PID $pid (종료 필요)"
  fi
done < /tmp/claude-agent-pids.txt
```

좀비가 있으면 추적된 PID만 종료한다.
```bash
while read pid; do
  if ps -p "$pid" > /dev/null 2>&1; then
    kill "$pid" 2>/dev/null
    echo "에이전트 PID $pid 종료"
  fi
done < /tmp/claude-agent-pids.txt
rm -f /tmp/claude-agent-pids.txt /tmp/claude-pids-before.txt /tmp/claude-pids-after.txt
```

**⚠️ 핵심 규칙**:
- **추적된 PID만 종료 가능** — spawn 전후 스냅샷으로 기록한 PID만 kill 대상
- **추적되지 않은 Claude 프로세스는 절대 종료 금지** — ps aux로 임의 판단하여 kill하지 말 것

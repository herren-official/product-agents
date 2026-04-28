---
name: b2b-backend-monitor
description: |
  플랜 기반 주기적 로그 모니터링. /api-test-plan으로 생성한 플랜의 키워드를 추적하고 배포 상태를 감시한다.
  다음 상황에서 사용할 것:
  - 배포 후 로그를 주기적으로 수집하고 키워드 기반 모니터링을 실행할 때
  - prod 배포 상태(EB/ECS)를 실시간 폴링으로 감시할 때
  다음 상황에서는 사용하지 않을 것:
  - 테스트 플랜을 새로 생성할 때 (/api-test-plan 커맨드 사용)
  - 모니터링 결과를 플랜에 반영할 때 (/plan-update 커맨드 사용)
  - 에러 진단이 필요할 때 (/troubleshoot 커맨드 사용)
allowed-tools: Read, Glob, Grep, Bash
user-invocable: true
---

$ARGUMENTS 에서 환경명과 플랜 파일 경로를 받아 주기적 로그 모니터링을 실행한다.
메인 컨텍스트에서 직접 수집 스크립트를 실행하고, 결과를 분석하여 사용자에게 보고한다.

## 입력 파싱
`$ARGUMENTS`를 공백으로 분리하여 첫 번째를 `{env}`, 나머지를 `{planFile}`로 파싱한다.
- `{env}`: 허용 환경: dev1, dev2, dev3, qa, prod. 이 외 값이 입력되면 "지원하지 않는 환경입니다: {env}. 허용 환경: dev1, dev2, dev3, qa, prod" 출력 후 중단한다.
  - dev 환경: 숫자 부분을 `{envNum}`으로 추출한다 (dev2 → 2).
  - qa 환경: `~/.claude/skills/api-test-plan-knowledge/references/log-source-mapping.md`의 "QA 환경" 테이블에서 매핑. QA에 배포되지 않은 모듈은 skip하고 "[QA 미배포] {모듈명} — dev 환경에서 `/monitor dev{N}`으로 별도 모니터링하세요"를 보고에 표시한다.
  - prod 환경: 플랜 파일의 모니터링 설정에 명시된 prod 로그 그룹을 그대로 사용한다.
- `{planFile}`: 플랜 md 파일 경로. 비어있으면 프로젝트 루트의 `.claude/plan/` 디렉토리에서 파일 수정 시각 기준 가장 최근의 `*-test-plan.md` 파일 1개를 자동 선택하고 "자동 선택: {파일명}"을 출력한다. 해당 디렉토리가 없거나 `*-test-plan.md` 파일이 없으면 "`.claude/plan/`에 플랜 파일이 없습니다. 경로를 직접 지정해 주세요." 출력 후 중단한다.

`$ARGUMENTS`가 비어있으면 사용법을 출력하고 중단한다:
```
사용법: /monitor <환경> [플랜파일]
예시: /monitor prod .claude/plan/deploy-231-test-plan.md
      /monitor dev2  (가장 최근 플랜 파일 자동 선택)
```

## 플랜 파일 읽기
1. `{planFile}`을 읽는다. 없으면 에러 출력 후 중단.
2. "모니터링 설정" 섹션에서 모듈별 로그 소스, 환경 오버라이드(`[env:qa]`), 키워드(필수/에러/부정/수량), 수집 주기를 추출한다.
3. "테스트 Phase" 섹션에서 Phase별 체크 키워드를 추출한다.
4. "모니터링 설정" 섹션이 없으면 에러 출력 후 중단.

## 로그 그룹 경로 결정
- `[env:qa]` 오버라이드: 해당 환경의 로그 그룹 사용
- dev: `{envNum}` 치환
- qa: QA 테이블에서 매핑
- prod: 플랜에 명시된 경로 사용

## Bash 권한 안내
settings.json을 수정하지 않는다.

**[필수] 첫 수집 실행 전에 반드시 아래 안내를 출력한다. 생략 금지:**
```
모니터링은 Bash를 반복 실행합니다. 매번 승인이 번거로우면
`claude --allowedTools Bash`로 세션을 재시작해 주세요.
현재 세션에서 계속 진행하려면 아무 키나 입력하세요.
```
사용자가 응답하면 첫 수집을 시작한다.

## 수집 스크립트 생성
`~/.claude/skills/api-test-plan-knowledge/references/collect-script-template.md`의 템플릿으로 모듈별 수집 스크립트를 생성한다. 플랜의 모니터링 설정에서 `(CloudWatch)` / `(SSH)` 표기로 스크립트 유형을 구분한다. 스크립트는 macOS 로컬에서 실행되는 것을 전제로 한다 (`date -v` 등 macOS 전용 문법 사용).

SSH 모듈(admin, crm-batch 등 EC2 직접 배포)의 로그 조회 명령에는 반드시 `sudo`를 붙인다 (로그 파일이 root 소유). 템플릿에 sudo가 포함되어 있지 않으면 수집 스크립트 생성 시 직접 삽입한다.
SSH 수집 시 시간 범위는 epoch 또는 `%Y-%m-%d %H:%M:%S` 형식으로 관리한다 (HH:MM:SS만 저장하면 날짜 경계에서 범위가 틀어짐). 템플릿의 SSH 섹션이 `%H:%M:%S`만 사용하는 경우, `%Y-%m-%d %H:%M:%S`로 변경하여 스크립트를 생성한다.

CloudWatch `filter-log-events`는 1MB/10,000건 제한이 있다. `nextToken` 감지를 위해 `--output json`으로 수집 후 `jq`로 `events[].message`를 추출하고, `nextToken` 필드가 존재하면 "[TRUNCATED] 로그가 잘렸습니다. 수집 주기를 줄이거나 키워드를 좁혀주세요."를 보고에 표시한다.

플랜에 "DB 체크" 섹션이 있으면 매 수집 주기마다 DB 접속 명령으로 쿼리를 실행한다. DB 접속 명령은 `~/.zshrc`에 정의된 쉘 함수를 사용한다 (prod: `proddb`, qa/dev: 사용자에게 확인).

## 배포 상태 체크 (prod 환경 전용)
`{env}`가 `prod`이고 플랜에 "P0: 배포 상태 확인" Phase가 있으면 수행한다.
P0 Phase가 없으면 배포 상태 체크를 건너뛰고 "P0 Phase가 없어 배포 상태 체크를 건너뜁니다."를 안내한다.

### 2단계 동작
- **대기 모드**: 시작 시 EB/ECS 현재 버전을 baseline으로 기록. 일반 수집 루프 진행.
- **실시간 모드**: 사용자가 "배포 시작"을 입력하면 전환. 15초 간격 폴링.
  - 플랜에 "배포 순서"가 명시되어 있으면 (예: backend → notification → admin), 해당 순서를 인식하여 아직 배포 차례가 아닌 모듈은 "대기 (순서: 3/3)" 등으로 표시한다.

**[필수] 배포 완료 판정 규칙**:
- baseline 기록 시점의 버전/태스크 정의를 저장한다.
- 배포 모드에서 모듈의 상태를 "정상" 또는 "배포 완료"로 표시하려면, 반드시 baseline과 비교하여 **새 버전이 감지되고** + **해당 버전이 Ready/Green 또는 PRIMARY runningCount==desiredCount**일 때만 표시한다.
- baseline과 동일한 버전이면 "배포 전" 또는 "대기"로 표시한다.
- ECS에서 deployment가 2개 이상이면 (ACTIVE + PRIMARY) "전환 중 (old: :N → new: :M)"으로 표시한다. "정상"으로 표시하지 않는다.
- EB에서 Yellow/Red이면 "안정화 중"으로 표시한다. "정상"으로 표시하지 않는다. EB가 10분 이상 Yellow/Red을 유지하면 **[CRITICAL]**로 에스컬레이션하고 `describe-events` 최근 5건을 출력한다.

### baseline 기록 (시작 시)
```bash
# EB
aws elasticbeanstalk describe-environments --profile mfa \
  --environment-names {EB환경명들} \
  --query 'Environments[].[EnvironmentName,Status,Health,HealthStatus,VersionLabel]' --output table
# ECS (--output json + jq로 파싱하여 서비스별 deployment 상태를 구조화)
aws ecs describe-services --profile mfa \
  --cluster {클러스터} --services {서비스} \
  --query 'services[].{name:serviceName,deployments:deployments[].{status:status,running:runningCount,desired:desiredCount,taskDef:taskDefinition}}' --output json
```

### "배포 시작" 시 — 15초 폴링
매 15초마다 baseline과 비교한다.

**[필수] 폴링 출력 규칙**:
- 매 15초 폴링마다 배포 상태 테이블을 **반드시 사용자에게 출력**한다.
- Bash for 루프로 여러 회차를 묶어 한번에 출력하는 것을 금지한다. 반드시 1회 수집 → 테이블 출력 → sleep background → 알림 시 다음 수집 순서로 진행한다.
- 이유: for 루프로 묶으면 루프가 끝날 때까지 사용자에게 아무것도 보이지 않는다.

폴링 판정 기준:
- **버전 변경**: "배포 감지: {모듈} {이전} → {신규}"
- **진행 중**: ECS deployment 2개 이상 → "배포 진행 중: {모듈} (running {N}/{desired})"
- **완료**: EB Ready+Green, ECS PRIMARY runningCount==desiredCount → "배포 완료: {모듈}"
- **실패**: EB Degraded/Severe, ECS 해당 모듈의 버전 변경 감지 시점으로부터 5분 이상 미완료 → **[CRITICAL]**. 플랜에 `timeout` 설정이 있으면 해당 값을 우선 사용한다. 실패 시 EB `describe-events` 최근 5건 또는 ECS `services[].events[]` 최근 5건을 함께 출력하여 원인을 즉시 파악한다.
- **EC2**: SSH 로그에 기동 완료 키워드 출현 → "기동 완료: {모듈}". 기동 키워드: Tomcat — `Server startup in`, Spring Boot — `Started`.

### 전 모듈 배포 완료 시
"전 모듈 배포 완료. 로그 모니터링으로 전환합니다." 출력 → baseline 갱신 → P0=OK → 일반 수집 루프 복귀.

## 모니터링 시작
환경, 플랜, 모니터링 대상 목록, 키워드, 사용 가능한 명령을 안내한 후 첫 수집을 실행한다.

## 수집 루프
초기화와 첫 수집 후, 내부 타이머로 주기적 수집을 반복한다.

### 타이머 구현
수집+보고 완료 후 `Bash(command: "sleep {초}", run_in_background: true)`로 다음 주기까지 대기.
sleep 완료 알림이 오면 **반드시** 다음 수집을 시작한다. 사용자 입력을 기다리지 않는다.
배치 등 주기가 다른 모듈은 마지막 수집 시각을 추적하여 주기 미도래 시 skip.

### 수집 → 분석 → 보고
각 모듈의 수집 스크립트를 Bash로 실행한 뒤, 수집된 로그에서 Grep으로 키워드별 출현 건수를 집계하여 보고한다.

**[필수] 출력 규칙**:
- 매 수집마다 아래 테이블 형식을 **반드시 사용자에게 출력**한다. 내부에서만 확인하고 요약하거나 생략하는 것을 금지한다.
- "정상입니다", "이상 없습니다" 같은 한 줄 요약으로 대체하지 않는다.
- 테이블 출력 후 추가 질문("계속할까요?", "종료할까요?")을 하지 않는다. 자동으로 다음 수집을 예약한다.
- 이상이 발견된 경우에만 테이블 아래에 "[WARNING]" 또는 "[CRITICAL]" 상세를 추가한다.
- **에러 키워드가 1건 이상 발생하면, 건수만 보고하지 말고 상위 3건의 실제 로그 내용을 함께 출력한다.** 사용자가 "뭐야?"라고 물어보기 전에 내용을 먼저 보여준다.
- 플랜에 "Phase별 신규 이벤트" 섹션이 없으면 해당 테이블을 생략한다. "DB 체크" 섹션이 없으면 해당 테이블을 생략한다.

```
## {시각} KST 보고 (#{N}회차, 수집: {from}~{to})

### 배포 상태 (prod, 배포 완료 후 생략)
| 모듈 | 상태 | 버전/태그 | 비고 |

### 키워드 체크
| 키워드 | 건수 | 상태 |
(필수: 0건이면 [WARNING], 에러: 출현 시 [WARNING], 부정: 출현 시 [CRITICAL], 수량: 플랜에 정의된 임계값 초과 시 [WARNING])

**자동 조사 규칙**: 필수 키워드가 3회 연속 0건이면 [WARNING]을 표시하는 것에 그치지 않고, 즉시 원인을 조사한다. DB 직접 조회, 다른 모듈 로그 교차 확인, 해당 API/배치의 실행 여부 확인 등을 수행하고 결과를 보고에 포함한다.

### Phase별 신규 이벤트 (플랜에 해당 섹션이 없으면 생략)
| 시간 | Phase | 상세 |

### DB 체크 (플랜에 해당 섹션이 없으면 생략)
| 테이블 | 전체 | 최근 {interval}분 | 비고 |

---
다음 수집: {시각} KST ({N}분 후)
```

**[필수] MFA 만료 감지 규칙**:
- 수집 결과에 `ExpiredTokenException`이 포함되면 해당 수집을 "0건"으로 보고하지 않는다.
- 즉시 **[MFA 만료]** 경고를 테이블에 표시하고, "MFA 코드를 알려주세요."를 출력한다.
- MFA가 만료된 상태에서 수집한 키워드 건수는 신뢰할 수 없으므로 "N/A"로 표시한다.

### 사용자 명령 처리
타이머 대기 중에도 수신:
- "모니터링 끝" / "stop" / "종료": 종료 절차로 이동
- "환경 전환 {env}" / "switch {env}": 환경 전환 후 즉시 수집
- "지금 수집" / "collect now": 즉시 수집 (기존 타이머 유지)
- "배포 시작" / "deploy start": 실시간 배포 모니터링 모드 전환 (prod 전용, 15초 폴링)
- "주기 {N}분" / "주기 {N}초" / "interval {N}m" / "interval {N}s": 수집 주기 동적 변경. 즉시 적용하고 "{기존}→{변경} 주기 변경 완료" 출력
- 위 명령에 해당하지 않는 입력은 무시하고 다음 수집을 계속한다.

## 환경 전환
`{env}` 변경 → 로그 그룹 재결정 → 수집 스크립트 재생성 → 즉시 수집.

## 종료
최종 요약을 출력한다:
```
## 모니터링 최종 요약
- 모니터링 기간: {시작} ~ {종료}
- 환경: {환경 목록}
- 총 수집 횟수: {N}회

### Phase별 결과
| Phase | 결과 | 비고 |

### 발견된 이슈
- {목록}

### 수집된 로그 파일
- ~/monitor-logs/{env}/{날짜}/{파일 목록}

### 다음 단계
- `/plan-update`으로 결과를 플랜에 반영할 수 있습니다.
- NOK Phase가 있으면 원인 확인 후 재모니터링하세요.
- 에러 해결이 필요하면 `/troubleshoot {에러 메시지}`를 실행하세요.
- 배포 실패 시 EB 이벤트(`describe-events`)와 ECS 서비스 이벤트(`services[].events[]`)를 직접 조회하여 원인을 파악합니다.
```

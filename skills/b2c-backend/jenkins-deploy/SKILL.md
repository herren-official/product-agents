---
name: b2c-backend-jenkins-deploy
description: 공비서 Jenkins(B2B 백엔드/프론트/B2C) 배포 트리거, 빌드 상태/로그 조회, 환경변수 조회 자동화. "젠킨스 배포", "dev1에 올려줘", "dev3 배포해줘", "b2c-api dev 배포", "빌드 상태", "젠킨스 로그", "deploy", "환경변수 보여줘" 요청 시 사용
allowed-tools: Bash, Read, AskUserQuestion
user-invocable: true
---

# Jenkins 배포 스킬

공비서 Jenkins 세 대(B2B 백엔드용, B2B 프론트용, B2C용)에 대한 배포 트리거, 빌드 상태/로그 조회, 환경변수 조회를 자동화한다. SSH 접속 후 Jenkins HTTP API + 파일시스템을 함께 사용한다.

## ⚠️ 절대 규칙 (안전 가드)

1. **prod 잡 트리거 금지**
   - 잡 이름이 `prod-*` 로 시작하면 트리거 요청을 받아도 **거절**한다.
   - 응답: "prod 배포는 안전을 위해 스킬이 트리거하지 않습니다. Jenkins UI에서 직접 진행해주세요."
   - 단, prod 잡의 **상태/로그/환경변수 조회는 허용**.

2. **부수효과 명령은 사용자 명시 동의 후만**
   - `POST /build`, `POST /buildWithParameters`, `POST /stop`, `POST /cancelQueue` 등은 잡 이름·환경·파라미터·환경변수까지 모두 보여주고 **마지막에 별도 컨펌** 후만 실행.
   - "권한 확인", "테스트로 한 번", "dry-run" 명목으로도 절대 미리 실행 금지. 권한 검증은 GET 계열만 사용.

3. **Step별 컨펌 강제 (배포 워크플로우 한정)**
   - 사용자가 "dev1 배포해줘" 식으로 한 번 명령했어도 **죽 진행하지 말 것**. 각 Step 끝에서 `AskUserQuestion`으로 다음 진행 여부를 묻는다.
   - 조회 전용 워크플로우(상태/로그/환경변수만)는 컨펌 강제 X.

4. **Jenkins ID/PW는 매번 입력받고, 어디에도 저장하지 않음**
   - 파일/메모리 저장 X, 로그 출력 X, 다음 턴 재사용 X.
   - 매 작업 시작 시 `AskUserQuestion`으로 받음.

## 접속 정보

| 대상 | SSH | 용도 |
|---|---|---|
| **B2B Jenkins** | `ssh -i ~/pem-key/gongbiz-b2b.pem ubuntu@jenkins-backend.gongbiz.kr` | CRM B2B **백엔드** dev1~5, admin/batch/notification, kakao chatbot |
| **Frontend Jenkins** | `ssh -i ~/pem-key/gongbiz-b2b.pem ec2-user@jenkins-frontend.gongbiz.kr` | CRM B2B **프론트** dev1~6, B2B consumer, settlement-batch |
| **B2C Jenkins** | `ssh -i ~/pem-key/dev-keypair-gongbiz-b2c.pem ec2-user@jenkins-b2c.gongbiz.kr` | B2C api/front, SSO, dev/qa/prod deploy 파이프라인 |

Jenkins 자체는 세 서버 모두 `http://localhost:8080`. anonymous=403 이라 `-u user:pass` BASIC AUTH 필요.

> **각 Jenkins의 계정/PW는 별도 사용자 DB.** 작업 시작 시 어느 Jenkins인지 확정한 뒤 그쪽 자격 증명을 받을 것.

## 잡 카탈로그 / 환경변수 토폴로지

- 잡 이름·키워드 매핑은 `references/jobs.md`
- 환경변수가 어디에서 오는지(파일 + Parameter Store + ECS Task Def)는 `references/env-config.md`

## 배포 워크플로우 (부수효과 — Step별 컨펌 강제)

### Step 0: 대상 잡 확정

사용자 요청을 `references/jobs.md`와 매칭해서:
1. 어느 Jenkins(B2B/Frontend/B2C)인지
2. 정확한 잡 이름

`prod-*` 잡이면 즉시 거절 (안전 가드 #1).

`AskUserQuestion`으로 매핑 결과 컨펌:
> "다음 잡으로 진행할까요?  
> Jenkins: B2B (jenkins-backend) / Job: gongbiz-crm-dev3-jdk17"

옵션: "이 잡 맞음 / 다른 잡으로 / 취소"

### Step 1: 빌드 파라미터 결정 (잡 파라미터 하나씩 사용자 명시)

잡의 빌드 파라미터(예: dev1~5 잡은 9개)를 **하나씩** 사용자에게 묻는다. 매번 default 값을 함께 보여주고, 사용자가 변경할지 결정하게.

**default 값 소스 (우선순위 순)**:
1. **마지막 성공 빌드(`lastSuccessfulBuild`)의 build.xml**에 들어있는 값 (ad-hoc 운영 변경이 반영됨)
2. 1번이 없으면 잡 config.xml의 `<defaultValue>`
3. `GIT_BRANCH`는 별도 처리: 사용자가 명시한 값 > 현재 git 브랜치(`git rev-parse --abbrev-ref HEAD` → `origin/<branch>`) > lastSuccessfulBuild 값 > config default

**진행 방식** — 각 파라미터마다 `AskUserQuestion`:
> "GIT_BRANCH = `origin/b2c-develop-GBIZ-...` (현재 브랜치)로 진행할까요?"
> 옵션: "이 값으로 / 다른 값 입력"
> "다른 값 입력" 선택 시 자유 입력 받기.

또는 한 번에 표로 보여주고 "전체 default 그대로 / 일부 변경" 묻는 방식도 가능 — 사용자가 9개 모두 default가 맞으면 한 번 컨펌으로 끝남.

```
다음 빌드 파라미터로 진행합니다 (default = lastSuccessfulBuild #N의 값):

  1. APPLICATION_NAME       = gongbiz-b2b
  2. ENV_NAME               = dev3-eb-gongbiz-crm-b2b-server
  3. S3_BUCKET_ZIP_FOLDER   = dev-gongbiz-crm-b2b-backend/dev3
  4. GIT_BRANCH             = origin/<현재 브랜치> ← 자동 제안
  5. DEV_SERVER             = dev3
  6. CRM_FRONT_SERVER_DOMAIN= crm-dev3-ssr.gongbiz.kr
  7. S3_BUCKET_URI          = gongbiz.kr
  8. SERVER_DOMAIN          = crm-dev3.gongbiz.kr
  9. CRM_B2B_MODULE         = gongbiz-crm-b2b-backend

전체 이대로 갈까요? 변경하고 싶은 번호가 있으면 알려주세요. (예: "4번 origin/feat-foo로", "이대로 진행")
```

확정된 파라미터 세트는 다음 단계들에서 재사용. Step 2의 y/n 루프 중에 이 값들은 변경되지 않음(사용자가 "파라미터 다시 받아줘" 명시 시만 Step 1 재실행).

### Step 2: 환경변수 표시 (**필수**, B2B/Frontend는 properties + Parameter Store 모두) + y/n 컨펌

빌드 트리거 전에 어떤 환경변수가 적용되는지 사용자에게 **반드시** 보여준다. 출처별 처리:

#### Step 2-A. B2B/Frontend 잡 (`jenkins-backend`, `jenkins-frontend`)

**(1) 파일시스템의 properties 표시**

```bash
ssh -i ~/pem-key/gongbiz-b2b.pem ubuntu@jenkins-backend.gongbiz.kr bash -s <<REMOTE
DEV=<dev1~6>
echo "=== cp 대상 파일 (timestamp/size) ==="
sudo ls -la /home/ubuntu/property/crm/application.properties \
            /home/ubuntu/property/crm/application-dev.properties \
            /home/ubuntu/property/crm/application-\$DEV.properties

echo ""
echo "=== application-\$DEV.properties (주석/빈 줄 제외) ==="
sudo grep -vE "^#|^\$" /home/ubuntu/property/crm/application-\$DEV.properties

echo ""
echo "=== spring.config.import (Parameter Store path) ==="
sudo grep "spring.config.import" /home/ubuntu/property/crm/application-dev.properties \
                                  /home/ubuntu/property/crm/application-\$DEV.properties 2>/dev/null
REMOTE
```

**(2) AWS Parameter Store 값 표시 (강제)**

`spring.config.import`에서 추출한 path 모두에 대해:

```bash
# 자격증명 체크 먼저
aws sts get-caller-identity --region ap-northeast-2 2>&1 | head -5
# Expired/InvalidClientToken이면 → b2c-backend-aws-mfa 스킬 안내 후 중단:
# "AWS 세션이 만료됐어요. /b2c-backend-aws-mfa 로 갱신 후 다시 시도해주세요."

# 권한 OK면 path별 fetch (이름 + 값, SecureString은 복호화)
for PATH_PREFIX in /config/gongbiz-crm-b2b-backend/common/ /config/gongbiz-crm-b2b-backend/dev/ ; do
  echo "=== $PATH_PREFIX ==="
  aws ssm get-parameters-by-path --path "$PATH_PREFIX" --recursive --with-decryption \
    --query "Parameters[].[Name,Value]" --output table
done
```

> **Parameter Store에 secret(API key, DB pw 등)이 들어있을 수 있음.** 출력 직전에 사용자에게 한 번 더 알릴 것:
> "Parameter Store 값에 비밀번호/키가 포함될 수 있습니다. 화면에 출력해도 될까요?" — Yes/No 컨펌 후 표시.

#### Step 2-B. B2C 잡 (`jenkins-b2c`)

```bash
# (1) 잡 파라미터 default + 파이프라인 build-arg
ssh -i ~/pem-key/dev-keypair-gongbiz-b2c.pem ec2-user@jenkins-b2c.gongbiz.kr \
  "sudo grep -E '<defaultValue>|--build-arg|environment|ECS_' /var/lib/jenkins/jobs/<JOB>/config.xml | head -50"

# (2) ECS Task Definition environment (자격증명 OK 가정)
aws ecs describe-task-definition --task-definition <TD_NAME> --region ap-northeast-2 \
  --query "taskDefinition.containerDefinitions[0].environment" --output table
```

#### Step 2 종료 — y/n 컨펌 + n→수정 후 재진입

표시한 ②③(properties + Parameter Store)에 변경할 게 없는지 사용자에게 물어 명시 컨펌을 받는다.

`AskUserQuestion` (또는 자유 질문):
> "Property / Parameter Store에 변경할 내용 없나요?
> - **y / ok** → 다음 단계 (자격증명) 진행
> - **n** → 외부에서 수정(AWS Console 또는 SSH로 properties 편집) 후 다시 'y' 보내주세요"

분기:
- `y` / `ok` → **Step 3** 으로 진행
- `n` → 사용자에게 안내:
  > "수정 완료 후 'y'를 보내주세요. 환경변수를 다시 조회해서 변경 반영 여부를 확인한 뒤 다시 y/n 묻겠습니다."
  
  → 사용자의 다음 입력(`y` 또는 새 명령) 대기. `y`가 들어오면 **Step 2를 처음부터 재실행** (properties 다시 cat + Parameter Store 다시 fetch) → 변경 반영된 값을 표시 → 다시 y/n 묻기 (필요시 또 n→수정→y 루프)
  > **주의**: y/n 루프 중에는 이전에 확정된 빌드 파라미터(Step 1)는 그대로 유지. 사용자가 빌드 파라미터를 다시 바꾸고 싶다면 명시적으로 "파라미터 다시 받아줘" 라고 해야 Step 1 재실행.

- "취소" 응답이면 워크플로우 종료.

### Step 3: Jenkins 자격 증명 받기

`AskUserQuestion`으로 ID/PW 받기 (해당 Jenkins용):
> "<jenkins-backend>의 Jenkins ID/PW를 알려주세요."

받은 후 read-only API로 검증:
```bash
ssh ... "curl -s -u 'NICKY:PW' -o /dev/null -w 'HTTP %{http_code}\n' http://localhost:8080/me/api/json"
```

`HTTP 200`이면 컨펌:
> "인증 통과 (HTTP 200, fullName: ...). 트리거 직전 단계로 갈까요?"

`HTTP 401/403`이면 다시 입력 요청.

### Step 4: 트리거 직전 최종 컨펌

모든 정보를 한 번에 보여주고 마지막 컨펌:

```
다음으로 트리거합니다:
- Jenkins: B2B (jenkins-backend)
- Job: gongbiz-crm-dev3-jdk17
- GIT_BRANCH: origin/b2c-develop-GBIZ-27317-...
- DEV_SERVER: dev3
- 적용될 properties: application.properties + application-dev.properties + application-dev3.properties
- Parameter Store: /config/gongbiz-crm-b2b-backend/common/ + .../dev/ (방금 표시한 값들)

진짜로 트리거할까요?
```

옵션: "트리거 / 취소 / 파라미터 다시"

### Step 5: 빌드 트리거 (POST)

PW를 ssh 인자에 평문으로 넣지 말 것 (`ps`로 노출됨). 환경변수로 전달:

```bash
ssh -i <KEY> <USER>@<HOST> "JU='$JENKINS_USER' JP='$JENKINS_PASS' bash -s" <<'REMOTE'
  set +x
  CRUMB=$(curl -s -u "$JU:$JP" "http://localhost:8080/crumbIssuer/api/json" \
    | sed -E 's/.*"crumb":"([^"]+)".*/\1/')
  curl -s -g -u "$JU:$JP" \
    -H "Jenkins-Crumb: $CRUMB" \
    -X POST \
    -o /dev/null -w "HTTP %{http_code}\n" \
    "http://localhost:8080/job/<JOB>/buildWithParameters?GIT_BRANCH=<BRANCH>&<PARAM2>=<VAL>"
REMOTE
unset JENKINS_USER JENKINS_PASS
```

응답 코드:
- `201 Created` → 큐 진입 성공
- `400` → 파라미터 오류
- `403` → 인증/crumb 실패
- `404` → 잡 이름 오타

> 파라미터가 없는 잡이면 `/build` 엔드포인트, 있으면 `/buildWithParameters`.

### Step 6: 빌드 모니터링 (옵션)

`AskUserQuestion`:
> "빌드가 큐에 들어갔습니다. 진행 상황을 모니터링할까요?"

옵션: "모니터링 / 종료"

모니터링 선택 시 — 30초 간격으로 상태 폴링 (또는 `/loop` 스킬 활용):
```bash
curl -s -g -u "$JU:$JP" "http://localhost:8080/job/<JOB>/lastBuild/api/json?tree=building,result,number,duration"
```

`result == SUCCESS` 가 되면 **Step 7 배포 완료 검증으로 자동 이어진다**.
`FAILURE / ABORTED` 면 Step 7 생략 + 콘솔 로그 tail 보여주고 종료.

### Step 7: 배포 완료 검증 (잡 타입별 분기)

빌드 SUCCESS ≠ 배포 완료. 실제 인프라 상태까지 확인.
잡 타입은 `references/env-config.md`의 "잡별 배포 타입" 테이블 참조.

#### 7-A. EB (Elastic Beanstalk) — `gongbiz-crm-dev{1..5}-jdk17`, prod tomcat 잡들

확인 명령 (AWS 자격증명 필요, 만료 시 `/b2c-backend-aws-mfa`):
```bash
aws elasticbeanstalk describe-environments \
  --environment-names <ENV_NAME> \
  --region ap-northeast-2 \
  --query "Environments[0].[EnvironmentName,Status,Health,HealthStatus,VersionLabel]" \
  --output table
```

ENV_NAME은 잡 config.xml의 `ENV_NAME` 파라미터 (예: `dev1-eb-gongbiz-crm-b2b-server`).

**판정**:
- ✅ 성공: `Status=Ready` AND `Health=Green` AND `HealthStatus=Ok`
- ⏳ 진행중: `Status=Updating` 또는 `Health=Grey` → 30초 후 재시도 권장
- ❌ 실패: `Health=Red` 또는 `HealthStatus=Severe/Degraded` → 사용자에게 알림 + EB 콘솔 안내

#### 7-B. ECS — `dev-gongbiz-b2c-*-deploy`, `gongbiz-crm-front-dev*-ecs`, consumer/batch 등

확인 명령:
```bash
aws ecs describe-services \
  --cluster <CLUSTER> --services <SERVICE> \
  --region ap-northeast-2 \
  --query "services[0].[serviceName,desiredCount,runningCount,pendingCount,deployments[].{status:status,runningCount:runningCount,desiredCount:desiredCount}]" \
  --output table
```

CLUSTER/SERVICE는 잡 config.xml의 `ECS_CLUSTER_NAME`, `ECS_SERVICE_NAME` 환경변수.
예: cluster=`dev-ecs-cluster-gongbiz-b2c`, service=`dev-ecs-service-gongbiz-b2c-api`

**판정**:
- ✅ 성공: `runningCount == desiredCount` AND `pendingCount == 0` AND `deployments[]`에 `PRIMARY`만 있고 `ACTIVE`(=구버전 배포 진행중) 없음. `INACTIVE`(=정리 안 끝남)도 없어야 함.
- ⏳ 진행중: `pendingCount > 0` 또는 `deployments[]`에 `ACTIVE` 존재 → 30초 후 재시도 권장
- ❌ 실패: `runningCount < desiredCount` 가 1분 이상 지속 → task 실패 가능성. `aws ecs list-tasks --cluster <C> --service-name <S> --desired-status STOPPED` 로 stopped task 확인 안내

> "중지됨(STOPPED) task는 있어도 OK" — 이전 배포 잔여물. **RUNNING task만 desiredCount만큼 있으면 정상**.

#### 7-C. EC2 직배포 (그 외 잡)

위 EB/ECS 패턴에 안 잡히는 잡 (예: notification, admin 일부, monorepo가 아닌 직접 SSH 배포 등).

확인 자동화 불가. 다음 메시지만 출력하고 종료:
> "이 잡은 EC2 직배포 패턴이라 자동 확인이 어렵습니다. 5분 후 다음 항목을 직접 확인해주세요:
> - 서비스 도메인 응답 (`curl <서버 도메인>/health` 또는 `/actuator/health`)
> - 서버 SSH 후 프로세스 확인 / 애플리케이션 로그 tail"

#### Step 7 종료

검증 결과를 사용자에게 알리고 종료. ⏳(진행중) 케이스면 `AskUserQuestion`:
> "아직 진행 중입니다. 다시 확인할까요?"
옵션: "30초 뒤 재확인 / 종료"

## 조회 워크플로우 (read-only — 컨펌 강제 X)

배포가 아니라 단순 조회면 step별 컨펌 없이 즉시 응답.

### 빌드 상태 확인

가벼운 조회는 인증 없이 SSH 파일시스템:
```bash
ssh ... bash -s <<'REMOTE'
  JOB="<JOB>"
  cat /var/lib/jenkins/jobs/$JOB/builds/permalinks 2>/dev/null
  LAST=$(grep "^lastCompletedBuild" /var/lib/jenkins/jobs/$JOB/builds/permalinks | awk '{print $2}')
  echo "--- last build #$LAST ---"
  grep -E "<result>|<duration>|<timestamp>" /var/lib/jenkins/jobs/$JOB/builds/$LAST/build.xml | head -5
REMOTE
```

> permalinks가 stale할 수 있으면 `ls /var/lib/jenkins/jobs/<job>/builds/ | grep -E '^[0-9]+$' | sort -n | tail -1`로 직접 확인.

실시간 상태는 인증 후:
```bash
curl -s -g -u "$JU:$JP" \
  "http://localhost:8080/job/<JOB>/api/json?tree=name,buildable,inQueue,lastBuild[number,result,building,timestamp,duration]"
```

### 콘솔 로그 조회

```bash
ssh ... bash -s <<'REMOTE'
  JOB="<JOB>"
  LAST=$(grep "^lastCompletedBuild" /var/lib/jenkins/jobs/$JOB/builds/permalinks | awk '{print $2}')
  tail -100 /var/lib/jenkins/jobs/$JOB/builds/$LAST/log
REMOTE
```

진행 중인 빌드 로그:
```bash
curl -s -g -u "$JU:$JP" "http://localhost:8080/job/<JOB>/<NUM>/consoleText" | tail -100
```

### 환경변수만 조회

배포 워크플로우의 Step 2-A/B를 Step별 컨펌 없이 단발성 실행. 단, Parameter Store 값 출력 직전 "secret 노출 가능 — 출력해도 되나요?" 컨펌은 유지.

### 마지막 빌드 파라미터 조회

"dev3 마지막 빌드 파라미터", "직전 배포 어떤 브랜치였지?", "last build params" 같은 요청.

#### 출력 전략 (2-stage)

| 단계 | 트리거 | 표시/저장 영역 | 위치 |
|---|---|---|---|
| **1차 (기본)** | "마지막 빌드 파라미터 보여줘" | ① Jenkins Pipeline 환경변수 (빌드 파라미터) **만** | 채팅에 표시 |
| **2차 (저장 요청 시)** | "환경변수 파일로 저장", "전체 환경변수 저장", "파일로 받아줘" 등 | ① + ② Jenkins Property + ③ AWS Parameter Store **모두** | `~/{JOB}-{BUILD}-환경변수.md` |

> 채팅엔 핵심(빌드 파라미터)만 — 보통 ~10개 키, secret 거의 없음.
> 디테일(properties/SSM, 평문 secret 다수)은 파일로 → 채팅창에 secret 통째로 남는 거 방지 + 사용자가 차분히 열어보고 사용 후 삭제.
> 사용자가 "마지막 빌드"를 묻는 시점에서는 ②③ 은 **현재 상태와 동일** (마지막 배포 = 현재 적용된 값). 과거 스냅샷 복원하지 않고 현재 값을 가져온다.

#### 잡 타입 가드

②③ 영역은 **jenkins-backend의 B2B 백엔드 잡** (`gongbiz-crm-dev{1..5}-jdk17`, prod tomcat 잡들)에서만 의미 있다. 그 외 잡(Frontend ECS, B2C, notification, batch 등)은 properties cp 패턴이 아니라 ECS Task Definition + Docker build-arg 기반이므로 저장 요청이 와도 동등한 데이터를 만들 수 없다 — 사용자에게 "이 잡은 ECS 패턴이라 환경변수 파일 저장은 지원되지 않습니다. ECS Task Definition은 `aws ecs describe-task-definition`으로 따로 조회하세요" 안내.

#### 1차) Jenkins Pipeline 환경변수만 — 채팅 표시 (기본)

`build.xml`에 빌드 시점의 파라미터 값이 그대로 남아있다 (인증 불필요).

```bash
ssh -i <KEY> <USER>@<HOST> bash -s <<'REMOTE'
JOB="<JOB>"
for KIND in lastCompletedBuild lastSuccessfulBuild; do
  NUM=$(sudo grep "^$KIND " /var/lib/jenkins/jobs/$JOB/builds/permalinks 2>/dev/null | awk '{print $2}')
  if [ -z "$NUM" ] || [ "$NUM" = "-1" ]; then continue; fi
  echo "=== [1/?] Jenkins Parameter — $KIND (#$NUM) ==="
  sudo cat /var/lib/jenkins/jobs/$JOB/builds/$NUM/build.xml 2>/dev/null | python3 -c "
import sys, xml.etree.ElementTree as ET
try:
    root = ET.fromstring(sys.stdin.read())
except ET.ParseError as e:
    print(f'  (parse error: {e})'); sys.exit(0)
for p in root.iter():
    if p.tag.endswith('ParameterValue'):
        name = p.findtext('name', '') or ''
        value = p.findtext('value', '') or ''
        if name:
            print(f'  {name} = {value}')
"
  echo "    (result: $(sudo grep -oE '<result>[^<]+' /var/lib/jenkins/jobs/$JOB/builds/$NUM/build.xml | sed 's/<result>//'))"
  echo ""
done
REMOTE
```

permalinks가 stale할 수 있으면 `sudo ls /var/lib/jenkins/jobs/$JOB/builds/ | grep -E '^[0-9]+$' | sort -n | tail -1` 로 실제 최신 빌드 번호 찾기.

#### 2차) 전체 환경변수를 파일로 저장 (사용자 명시 요청 시)

트리거 키워드: "환경변수 파일로 저장", "전체 환경변수 저장", "파일로 받아줘", "save env to file" 등.

**산출물**:
- 경로: `~/{JOB}-{BUILD}-환경변수.md` (예: `~/gongbiz-crm-dev5-jdk17-256-환경변수.md`)
- 권한: `chmod 600` (secret 평문 포함이라 다른 사용자 접근 차단)
- 형식: Markdown (3영역을 섹션으로 분리)
- 저장 후: 콘솔에 절대 경로 + 파일 크기 + secret 경고 한 줄 출력

**흐름**:
1. AWS 자격증명 사전 체크 — Expired면 `/b2c-backend-aws-mfa` 안내 후 중단
2. SSH(jenkins-backend) — Jenkins Parameter + Property cp 대상 파일 내용 + cp basename 추출 (아래 B-단계)
3. 로컬 — 코드 레포에서 `spring.config.import` SSM path 추출 (B2-단계)
4. 로컬 — 각 SSM path에 대해 `aws ssm get-parameters-by-path --with-decryption` fetch
5. 로컬 — 모든 영역을 합쳐 markdown 파일 생성 → `chmod 600` → 절대 경로 출력

##### B-단계: SSH로 Jenkins Property 수집

config.xml의 `cp` 라인을 동적으로 추출해서 적용된 properties 파일들을 찾고, 각 파일 내용을 모은다.

cp 경로 안의 placeholder는 두 종류가 섞여 있다:
- **빌드 파라미터** (`${DEV_SERVER}`, `${CRM_B2B_MODULE}` 등) — `build.xml`의 `<parameters>` 에서 추출
- **셸 스크립트 변수** (`${BASE_PATH}` 등) — config.xml의 빌더 셸 스크립트 안에 `BASE_PATH=/home/ubuntu/property/crm` 식으로 정의됨

후자는 잡마다 다를 수 있어 **known 기본값을 시드**한 뒤 config.xml에서 추가로 grep해 보강한다.

```bash
# 결과를 로컬에서 받기 위해 SSH 출력을 그대로 캡처
SSH_OUT=$(ssh -i ~/pem-key/gongbiz-b2b.pem ubuntu@jenkins-backend.gongbiz.kr bash -s <<'REMOTE'
JOB="<JOB>"
NUM=$(sudo grep "^lastCompletedBuild " /var/lib/jenkins/jobs/$JOB/builds/permalinks | awk '{print $2}')
echo "BUILD_NUM=$NUM"

declare -A PARAMS
PARAMS[BASE_PATH]="/home/ubuntu/property/crm"

while IFS='=' read -r k v; do
  v="${v//&quot;/}"; v="${v//&apos;/}"; v="${v//\'/}"; v="${v//\"/}"
  [ -n "$k" ] && [ -n "$v" ] && PARAMS[$k]="$v"
done < <(sudo cat /var/lib/jenkins/jobs/$JOB/config.xml \
         | sed 's/<[^>]*>//g' \
         | grep -oE '^[[:space:]]*[A-Z_][A-Z0-9_]*=[^ <&]+' \
         | sed 's/^[[:space:]]*//')

while IFS='=' read -r k v; do PARAMS[$k]="$v"; done < <(
  sudo cat /var/lib/jenkins/jobs/$JOB/builds/$NUM/build.xml | python3 -c "
import sys, xml.etree.ElementTree as ET
root = ET.fromstring(sys.stdin.read())
for p in root.iter():
    if p.tag.endswith('ParameterValue'):
        n = p.findtext('name','') or ''; v = p.findtext('value','') or ''
        if n: print(f'{n}={v}')")

PROP_FILES=$(sudo grep -oE 'cp [^ ]*\.properties' /var/lib/jenkins/jobs/$JOB/config.xml | awk '{print $2}' | sort -u)
RESOLVED=()
for f in $PROP_FILES; do
  for _ in 1 2 3; do for k in "${!PARAMS[@]}"; do f="${f//\$\{$k\}/${PARAMS[$k]}}"; done; done
  RESOLVED+=("$f")
done

# 영역별 구분자로 묶어서 stdout
echo "===PARAM_BEGIN==="
sudo cat /var/lib/jenkins/jobs/$JOB/builds/$NUM/build.xml | python3 -c "
import sys, xml.etree.ElementTree as ET
root = ET.fromstring(sys.stdin.read())
for p in root.iter():
    if p.tag.endswith('ParameterValue'):
        n = p.findtext('name','') or ''; v = p.findtext('value','') or ''
        if n: print(f'{n}={v}')"
echo "===PARAM_END==="

for f in "${RESOLVED[@]}"; do
  echo "===PROP_BEGIN===$f==="
  sudo test -f "$f" && sudo cat "$f"
  echo "===PROP_END==="
done

echo "===BASENAMES_BEGIN==="
for f in "${RESOLVED[@]}"; do basename "$f"; done
echo "===BASENAMES_END==="
REMOTE
)
```

##### B2-단계: 로컬에서 SSM path 추출

```bash
REPO_RESOURCES="/Users/nicky/IdeaProjects/gongbiz-crm-b2b-backend/gongbiz-crm-b2b-backend/src/main/resources"
BASENAMES=$(echo "$SSH_OUT" | sed -n '/===BASENAMES_BEGIN===/,/===BASENAMES_END===/p' | grep -v '===')
SSM_PATHS=$(for base in $BASENAMES; do
  [ -f "$REPO_RESOURCES/$base" ] && grep "spring.config.import" "$REPO_RESOURCES/$base" 2>/dev/null
done | grep -oE 'aws-parameterstore:[^,]+/' | sed 's|aws-parameterstore:||' | sort -u)
```

코드 레포에 없으면 `references/env-config.md` 정적 매핑(잡 → profile → SSM path) 사용을 fallback으로.

##### 파일 저장: markdown 생성 + chmod 600 + 경로 출력

```bash
JOB="<JOB>"; BUILD_NUM=$(echo "$SSH_OUT" | grep '^BUILD_NUM=' | cut -d= -f2)
OUT="$HOME/${JOB}-${BUILD_NUM}-환경변수.md"

{
  echo "# ${JOB} build #${BUILD_NUM} 환경변수"
  echo ""
  echo "- 생성: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "- ⚠️ 이 파일은 DB password / API key / sentry DSN 등 secret을 평문으로 포함합니다. 사용 후 삭제하거나 외부에 공유하지 마세요."
  echo ""

  echo "## [1/3] Jenkins Pipeline 환경변수 (빌드 파라미터)"
  echo ""
  echo '```'
  echo "$SSH_OUT" | sed -n '/===PARAM_BEGIN===/,/===PARAM_END===/p' | grep -v '==='
  echo '```'
  echo ""

  echo "## [2/3] Jenkins Property (jenkins-backend 파일시스템, 현재 상태)"
  echo "Spring이 아래 순서로 머지 — 뒤쪽이 앞쪽을 override"
  echo ""
  echo "$SSH_OUT" | awk '
    /^===PROP_BEGIN===/ { sub(/^===PROP_BEGIN===/,""); sub(/===$/,""); print "### " $0 ""; print "```properties"; in_block=1; next }
    /^===PROP_END===/   { print "```\n"; in_block=0; next }
    in_block { print }
  '

  echo "## [3/3] AWS Parameter Store (현재 상태)"
  echo ""
  for SSM_PATH in $SSM_PATHS; do
    echo "### $SSM_PATH"
    echo '```'
    aws ssm get-parameters-by-path --path "$SSM_PATH" --recursive --with-decryption \
      --region ap-northeast-2 \
      --query "Parameters[].[Name,Value]" --output text \
      | sed "s|^${SSM_PATH}||" \
      | awk -F'\t' '{ printf "%s = %s\n", $1, $2 }'
    echo '```'
    echo ""
  done
} > "$OUT"

chmod 600 "$OUT"

echo ""
echo "✅ 저장 완료"
echo "   경로: $OUT"
echo "   크기: $(wc -c < "$OUT") bytes ($(wc -l < "$OUT") lines)"
echo "   ⚠️ secret 평문 포함 — 사용 후 'rm $OUT'"
```

#### 부록: SSM 키 한두 개만 조회 (저장 안 함)

사용자가 "spring.datasource.hikari.password 값만 보여줘" 같이 단건 명시 요청 시 — 파일 저장하지 말고 채팅에 단건 출력:

```bash
aws ssm get-parameter --name "/config/gongbiz-crm-b2b-backend/dev/spring.datasource.hikari.password" \
  --with-decryption --region ap-northeast-2 \
  --query "Parameter.Value" --output text
```

여러 개 묶어서:
```bash
aws ssm get-parameters --names \
  "/config/.../spring.datasource.hikari.password" \
  "/config/.../spring.datasource.hikari.username" \
  --with-decryption --region ap-northeast-2 \
  --query "Parameters[].[Name,Value]" --output text
```

#### 특정 빌드 번호 지정

> "dev3 build #218 파라미터 보여줘" — 1차 스크립트의 `NUM` 또는 2차 흐름의 `BUILD_NUM`을 직접 지정.
> 단, 그 빌드 시점의 properties / Parameter Store는 보존되어 있지 않으므로 ②③은 항상 "현재 상태" 라고 명시할 것.

## 트러블슈팅

- **HTTP 401**: 계정/PW 자체가 안 맞음. **세 Jenkins는 사용자 DB가 별도일 수 있음** — 어느 Jenkins 자격 증명을 받았는지 확인.
- **HTTP 403 (인증 실패)**: ID는 맞지만 권한 없음. 또는 crumb 문제.
- **HTTP 403 with crumb error**: `crumbIssuer/api/json`이 빈 응답이면 `Jenkins-Crumb` 헤더 대신 `.crumb` 쿠키와 함께 시도.
- **HTTP 404**: 잡 이름 오타. `references/jobs.md` 또는 `ssh ... "ls /var/lib/jenkins/jobs/"`로 확인.
- **`curl: (3) [globbing] bad range`**: URL의 `[]` 때문. `-g` 옵션 추가.
- **AWS `ExpiredToken`**: `/b2c-backend-aws-mfa` 스킬로 세션 갱신 후 재시도.
- **SSH timeout**: 사용자 wifi/IP 변경 안내. 공비서 Jenkins는 IP allowlist 기반.

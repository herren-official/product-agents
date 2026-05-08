# 환경변수 토폴로지 & 조회 가이드

각 Jenkins/잡이 환경변수를 어디에서 가져오는지, 어떻게 조회/수정하는지 정리.

## B2B Jenkins (`jenkins-backend`) — 파일시스템 + Parameter Store

### 1) Jenkins 서버 파일시스템 (`/home/ubuntu/property/crm/`)

빌드 시점에 `cp` 로 워크스페이스의 `src/main/resources/` 에 주입.

```
/home/ubuntu/property/crm/
├── application.properties              ← 모든 잡에서 사용 (공통)
├── application-dev.properties          ← dev 공통
├── application-dev1.properties         ← dev1 전용 (DEV_SERVER=dev1 일 때)
├── application-dev2.properties
├── application-dev3.properties
├── application-dev4.properties
├── application-dev5.properties
├── application-dev6.properties
├── prod/
│   ├── application-prod.properties     ← prod 공통
│   ├── application-web.properties      ← prod web 서버 (Tomcat)
│   ├── application-app.properties      ← prod app 서버 (Tomcat)
│   └── application-kakao.properties    ← prod kakao 챗봇
├── apache_httpd/                       ← Apache proxy 설정
└── front/                              ← 프론트용
    ├── dev/
    └── prod/
```

**잡별 cp 매핑**:
| 잡 | 사용 properties (cp 대상) |
|---|---|
| `gongbiz-crm-dev{1..5}-jdk17` | `application.properties` + `application-dev.properties` + `application-dev{N}.properties` |
| `prod-...-app-server-monorepo-tomcat` | `application.properties` + `prod/application-prod.properties` + `prod/application-app.properties` + `prod/application-web.properties` + `prod/application-kakao.properties` |
| `prod-...-web-server-monorepo-tomcat` | (유사 — 잡별 config.xml의 cp 라인 확인) |
| `prod-...-kakao-chatbot-server-monorepo-tomcat` | (유사) |

조회 예시:
```bash
ssh -i ~/pem-key/gongbiz-b2b.pem ubuntu@jenkins-backend.gongbiz.kr 'sudo cat /home/ubuntu/property/crm/application-dev3.properties'
```

### 2) AWS Parameter Store (런타임 fetch)

`application-{profile}.properties` 안의 `spring.config.import` 라인이 path 정의.

```
spring.config.import=optional:aws-parameterstore:/config/gongbiz-crm-b2b-backend/common/,optional:aws-parameterstore:/config/gongbiz-crm-b2b-backend/dev/
```

| 프로파일 | Parameter Store path |
|---|---|
| `dev` | `/config/gongbiz-crm-b2b-backend/common/` + `/config/gongbiz-crm-b2b-backend/dev/` |
| `prod` | `/config/gongbiz-crm-b2b-backend/common/` + `/config/gongbiz-crm-b2b-backend/prod/` |
| `app` | `/config/gongbiz-crm-b2b-backend/app/` |
| `kakao` | `/config/gongbiz-crm-b2b-backend/kakao/` |
| `web` | `/config/gongbiz-crm-b2b-backend/web/` |

같은 패턴 사용 모듈: `gongbiz-crm-b2b-admin`, `gongbiz-crm-b2b-consumer`, `gongbiz-crm-batch`, `gongbiz-lambda`.

조회 (AWS CLI, AWS 자격증명 필요):
```bash
# path 하위 파라미터 이름 목록
aws ssm get-parameters-by-path --path "/config/gongbiz-crm-b2b-backend/dev/" --recursive --query "Parameters[].Name"

# 특정 파라미터 값
aws ssm get-parameter --name "/config/gongbiz-crm-b2b-backend/dev/some.key" --with-decryption --query "Parameter.Value"
```

> SecureString은 `--with-decryption` + KMS decrypt 권한 필요.

## B2C Jenkins (`jenkins-b2c`) — Docker build-arg + ECS

`/home/ec2-user/`에 properties 디렉토리 없음. 환경변수 출처 4갈래:

### A) 잡 파라미터 default (`config.xml`)

각 잡의 빌드 파라미터 default 값 — Jenkins UI 또는 config.xml 직접 편집으로 변경.

| 잡 | 주요 환경변수 파라미터 |
|---|---|
| `dev-gongbiz-b2c-api-deploy` | `ECR_URL`, `CRM_BACKEND_DEV_HOST`, `CRM_BACKEND_API_DEV_HOST`, `GIT_BRANCH` (default `origin/b2c-develop`) |
| `dev-gongbiz-b2c-front-deploy` | (유사 — config.xml 확인) |
| `dev-gongbiz-crm-b2b-api-deploy` | (신 API 측 동일 패턴) |

### B) Docker build-arg (파이프라인 안)

파이프라인 스크립트의 `docker.build` 명령 인자.

예시 (`dev-gongbiz-b2c-api-deploy`):
```groovy
docker.build("...", "--build-arg SPRING_PROFILES_ACTIVE=dev 
                     --build-arg CRM_BACKEND_DEV_HOST=${CRM_BACKEND_DEV_HOST} 
                     --build-arg CRM_BACKEND_API_DEV_HOST=${CRM_BACKEND_API_DEV_HOST}")
```

→ 변경하려면 잡의 파이프라인 스크립트(`config.xml`의 `<script>`) 또는 코드 레포의 `docker/{module}/Dockerfile` 수정.

### C) ECS Task Definition `containerDefinitions[].environment`

배포 대상 ECS Task의 환경변수.

예시 (dev B2C API):
- ECS cluster: `dev-ecs-cluster-gongbiz-b2c`
- ECS service: `dev-ecs-service-gongbiz-b2c-api`
- Task definition: `dev-ecs-td-gongbiz-b2c-api`

조회:
```bash
aws ecs describe-task-definition --task-definition dev-ecs-td-gongbiz-b2c-api \
  --query "taskDefinition.containerDefinitions[0].environment"
```

### D) 코드 레포의 `application-{profile}.{properties|yml}` (Spring 측)

`SPRING_PROFILES_ACTIVE=dev` → Docker 이미지 안의 `application-dev.{properties|yml}` 로드.
변경: `gongbiz-crm-b2b-backend` 레포의 해당 모듈 properties 수정 + PR.

위치 예:
- `b2c-gongbiz-api/src/main/resources/application-dev.yml`
- `gongbiz-crm-b2b-api/src/main/resources/application-dev.properties` (있다면)

## 잡별 배포 타입 (배포 완료 검증 시 분기 기준)

빌드 SUCCESS 후 실제 인프라까지 정상 반영됐는지 확인하는 방법은 잡이 어디로 배포하느냐에 따라 다르다.
잡 config.xml의 빌더/스크립트에 어떤 AWS 명령이 호출되는지로 구분.

### EB (Elastic Beanstalk)
config.xml 안에 `aws elasticbeanstalk update-environment` 가 보이면 EB.

| 잡 | EB Application | EB Environment |
|---|---|---|
| `gongbiz-crm-dev1-jdk17` | `gongbiz-b2b` | `dev1-eb-gongbiz-crm-b2b-server` |
| `gongbiz-crm-dev2-jdk17` | `gongbiz-b2b` | `dev2-eb-gongbiz-crm-b2b-server` |
| `gongbiz-crm-dev3-jdk17` | `gongbiz-b2b` | `dev3-eb-gongbiz-crm-b2b-server` |
| `gongbiz-crm-dev4-jdk17` | `gongbiz-b2b` | `dev4-eb-gongbiz-crm-b2b-server` |
| `gongbiz-crm-dev5-jdk17` | `gongbiz-b2b` | `dev5-eb-gongbiz-crm-b2b-server` |
| `prod-gongbiz-crm-b2b-app-server-monorepo-tomcat` | `gongbiz-b2b` | `prod-eb-gongbiz-crm-b2b-app` |
| `prod-gongbiz-crm-b2b-web-server-monorepo-tomcat` | `gongbiz-b2b` | `prod-eb-gongbiz-crm-b2b-web` (확인 필요) |
| `prod-gongbiz-crm-b2b-kakao-chatbot-server-monorepo-tomcat` | `gongbiz-b2b` | `prod-eb-gongbiz-crm-b2b-kakao` (확인 필요) |

검증: `aws elasticbeanstalk describe-environments --environment-names <env>` → `Status=Ready, Health=Green, HealthStatus=Ok`

### ECS
config.xml 안에 `aws ecs update-service` 가 보이면 ECS.

| 잡 | ECS Cluster | ECS Service |
|---|---|---|
| `dev-gongbiz-b2c-api-deploy` | `dev-ecs-cluster-gongbiz-b2c` | `dev-ecs-service-gongbiz-b2c-api` |
| `dev-gongbiz-b2c-front-deploy` | (확인 필요) | (확인 필요) |
| `dev-gongbiz-crm-b2b-api-deploy` | (확인 필요) | (확인 필요) |
| `dev-gongbiz-crm-b2b-batch-deploy` | (확인 필요) | (확인 필요) |
| `dev-gongbiz-sso-deploy` | (확인 필요) | (확인 필요) |
| `gongbiz-crm-front-dev1-ecs` ~ `dev6-ecs` | (확인 필요) | (확인 필요, dev6는 jenkins-frontend만) |
| `dev-gongbiz-crm-b2b-consumer` | (확인 필요) | (확인 필요) |
| `dev-gongbiz-crm-settlement-batch` | (확인 필요) | (확인 필요) |

> 처음 다루는 잡이면 `sudo grep -E "ECS_CLUSTER|ECS_SERVICE|ECS_TASK_DEFINITION" /var/lib/jenkins/jobs/<JOB>/config.xml` 로 즉석 확인.

검증: `aws ecs describe-services --cluster <C> --services <S>` → `runningCount == desiredCount`, `pendingCount == 0`, deployments에 `PRIMARY`만.

### EC2 직배포 (자동 확인 불가)
EB도 ECS도 아닌 잡 (SSH로 jar/war를 직접 올리거나, 별도 패턴). 자동 검증 불가 → "5분 후 직접 확인 부탁드립니다" 안내만.

## 조회 워크플로우 권장 순서

1. **잡 이름 확정** → `references/jobs.md`
2. 잡이 어느 Jenkins(B2B/B2C)인지 → 패턴 결정
3. **B2B**: SSH로 `/home/ubuntu/property/crm/` 의 cp 대상 properties 표시 → `spring.config.import` 라인 추출 → Parameter Store path 명시
4. **B2C**: 잡 config.xml의 파라미터 default + 파이프라인 안 build-arg + ECS task def name 표시
5. 사용자가 더 깊이 원하면 → SSM `get-parameters-by-path` 또는 `describe-task-definition` 호출 (AWS 자격증명 필요)

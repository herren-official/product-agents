# Jenkins 잡 카탈로그

`ssh ... "ls /var/lib/jenkins/jobs/"` 결과 기준 (2026-05-08).
신규 잡 추가/이름 변경 시 이 문서를 업데이트.

## B2B Jenkins (`ubuntu@jenkins-backend.gongbiz.kr`)

### CRM B2B Backend (개발)
| 잡 이름 | 환경 | 설명 |
|---|---|---|
| `gongbiz-crm-dev1-jdk17` ~ `gongbiz-crm-dev5-jdk17` | dev1~5 | CRM B2B 백엔드 EB 배포 (FreeStyleProject) |
| `dev-gongbiz-batch-jdk17` | dev | CRM 배치 |
| `dev-crm-admin-jdk17` | dev | CRM 어드민 |

주요 파라미터: `APPLICATION_NAME`, `ENV_NAME`, `S3_BUCKET_ZIP_FOLDER`, `GIT_BRANCH` (default `origin/deploy`), `DEV_SERVER`, `CRM_FRONT_SERVER_DOMAIN`, `S3_BUCKET_URI`, `SERVER_DOMAIN`, `CRM_B2B_MODULE`

### CRM B2B Frontend (개발) — ⚠️ deprecated, **Frontend Jenkins 사용**
| 잡 이름 | 비고 |
|---|---|
| `gongbiz-crm-front-dev1-ecs` ~ `gongbiz-crm-front-dev5-ecs` | jenkins-backend에 남아있지만 운영은 jenkins-frontend 쪽 동명 잡으로 |
| `front-dev-ecs-warm-up-schedular` | 워밍업 스케줄러 (확인 필요) |
| `front-dev-ecs-shutdown-scheduler` | 셧다운 스케줄러 (확인 필요) |
| `front-dev-ecs-task-executor` | 태스크 실행기 (확인 필요) |

### Notification (개발)
| 잡 이름 | 설명 |
|---|---|
| `dev-gongbiz-notification-monorepo` | 알림 서비스 |
| `dev-gongbiz-notification-batch-monorepo` | 알림 배치 |

### 기타 (개발)
| 잡 이름 | 설명 |
|---|---|
| `dev-gongbiz-insta-crawl-server` | 인스타 크롤러 |
| `gongbiz-crm-pipeline-template` | 파이프라인 템플릿 (실행용 X) |
| `gongbiz-crm-dev-jdk17-warm-up-schedular` | dev 워밍업 |
| `gongbiz-crm-dev-jdk17-shutdown-scheduler` | dev 셧다운 |

### Prod (⚠️ 스킬 트리거 금지 — 조회만)
- `prod-b2b-crm-backend-server-deploy-sequential-pipeline`
- `prod-gongbiz-crm-b2b-app-server-monorepo`
- `prod-gongbiz-crm-b2b-app-server-monorepo-tomcat`
- `prod-gongbiz-crm-b2b-front-ecs-deploy-pipeline`
- `prod-gongbiz-crm-b2b-web-server-monorepo-tomcat`
- `prod-gongbiz-crm-b2b-kakao-chatbot-server-monorepo-tomcat`
- `prod-gongbiz-crm-kakao-chatbot-server-monorepo`
- `prod-gongbiz-notification-monorepo`
- `prod-gongbiz-notification-batch-monorepo`
- `gongbiz-admin-monorepo`, `gongbiz-batch-monorepo` (운영 통합 잡)
- `gongbiz-crm-front-prod-ecs-web`, `gongbiz-crm-front-prod-ecs-webview`

### 기타 운영 잡 (별도 서비스)
- `gongnail-admin-old`, `gongnail-appapi`, `heja-box`

## Frontend Jenkins (`ec2-user@jenkins-frontend.gongbiz.kr`)

키페어는 `gongbiz-b2b.pem` 공유, 사용자는 `ec2-user`.
**계정/PW가 jenkins-backend와 다를 수 있음** (별도 사용자 DB).

### CRM B2B Frontend (개발)
| 잡 이름 | 환경 |
|---|---|
| `gongbiz-crm-front-dev1-ecs` ~ `gongbiz-crm-front-dev6-ecs` | dev1~6 (ECS). dev6는 여기에만 존재 |

### B2B Consumer / Settlement Batch (개발)
| 잡 이름 | 설명 |
|---|---|
| `dev-gongbiz-crm-b2b-consumer` | Kafka 컨슈머 dev |
| `dev-gongbiz-crm-settlement-batch` | 정산 배치 dev |

### 기타 (개발/스케줄)
| 잡 이름 | 설명 |
|---|---|
| `dev-ecs-task-executor` | ECS 태스크 실행기 |
| `scheduler-docker-cache-cleanup` | Docker 캐시 정리 스케줄 |
| `공비서-B2B-프론트-시작배치` / `~중지배치` | 프론트 EC2/ECS 시작/중지 |

### Prod (⚠️ 스킬 트리거 금지 — 조회만)
- `prod-gongbiz-crm-b2b-consumer`
- `prod-gongbiz-crm-settlement-batch`
- `gongbiz-crm-front-prod-ecs-image-builder`
- `gongbiz-crm-front-prod-ecs-web-deploy`
- `gongbiz-crm-front-prod-ecs-webview-deploy`
- `woody-test-gongbiz-crm-front-prod-ecs-image-builder` (테스트용으로 보이나 prod 접두 — 조회만)

## B2C Jenkins (`ec2-user@jenkins-b2c.gongbiz.kr`)

### Deploy 파이프라인 (모두 WorkflowJob)
| 잡 이름 | 환경 | 대상 |
|---|---|---|
| `dev-gongbiz-b2c-api-deploy` | dev | B2C API |
| `qa-gongbiz-b2c-api-deploy` | qa | B2C API |
| `prod-gongbiz-b2c-api-deploy` ⚠️ | prod | B2C API |
| `dev-gongbiz-b2c-front-deploy` | dev | B2C 프론트 |
| `qa-gongbiz-b2c-front-deploy` | qa | B2C 프론트 |
| `prod-gongbiz-b2c-front-deploy` ⚠️ | prod | B2C 프론트 |
| `dev-gongbiz-crm-b2b-api-deploy` | dev | CRM B2B 신규 API (Spring Boot 3.3) |
| `qa-gongbiz-crm-b2b-api-deploy` | qa | CRM B2B 신규 API |
| `prod-gongbiz-crm-b2b-api-deploy` ⚠️ | prod | CRM B2B 신규 API |
| `dev-gongbiz-crm-b2b-batch-deploy` | dev | CRM B2B 배치 |
| `prod-gongbiz-crm-b2b-batch-deploy` ⚠️ | prod | CRM B2B 배치 |
| `dev-gongbiz-sso-deploy` | dev | SSO |
| `dev-gongbiz-sso-deploy-by-blug-green` | dev | SSO Blue/Green |
| `prod-gongbiz-sso-deploy` ⚠️ | prod | SSO |
| `prod-gongbiz-sso-deploy-blue-green` ⚠️ | prod | SSO Blue/Green |

주요 파라미터: `GIT_BRANCH` (default `origin/b2c-develop`), `GIT_CREDENTIALS_ID`, `AWS_CREDENTIALS_ID`, `ECR_URL`, `CRM_BACKEND_DEV_HOST`, `CRM_BACKEND_API_DEV_HOST`

### 서버 시작/중지 배치 (스케줄러용, 수동 트리거 거의 X)
- `공비서-B2B-For-B2C-개발서버-시작배치` / `~중지배치`
- `공비서-B2C-개발서버-시작배치` / `~중지배치`
- `공비서-B2C-QA서버-시작배치` / `~중지배치`
- `공비서-키클락-개발서버-시작배치` / `~중지배치`
- `공비서-B2C-젠킨스-도커-이미지-정리-배치`

## 사용자 표현 ↔ 잡 이름 매핑 가이드

매핑이 모호하면 `AskUserQuestion`으로 확인.

| 사용자 표현 예시 | 후보 잡 |
|---|---|
| "dev1 배포해줘" (모호) | 백엔드/프론트 어느 쪽인지 `AskUserQuestion`으로 확인 |
| "백엔드 dev1", "API dev1", "dev1 서버 배포" | B2B `gongbiz-crm-dev1-jdk17` |
| "dev3에 내 브랜치 올려줘" (백엔드 맥락) | B2B `gongbiz-crm-dev3-jdk17`, `GIT_BRANCH=origin/<현재 브랜치>` |
| "프론트 dev1", "front dev1" | Frontend `gongbiz-crm-front-dev1-ecs` |
| "dev6" (백엔드는 dev5까지) | Frontend `gongbiz-crm-front-dev6-ecs` |
| "consumer 배포", "kafka 컨슈머" | Frontend `dev-gongbiz-crm-b2b-consumer` |
| "settlement", "정산 배치" | Frontend `dev-gongbiz-crm-settlement-batch` |
| "b2c api dev", "b2c-api 배포" | B2C `dev-gongbiz-b2c-api-deploy` |
| "b2c front dev" | B2C `dev-gongbiz-b2c-front-deploy` |
| "qa b2c api" | B2C `qa-gongbiz-b2c-api-deploy` |
| "crm b2b api dev" (신 API) | B2C `dev-gongbiz-crm-b2b-api-deploy` |
| "b2b batch", "crm batch" | 모호함. B2C `dev-gongbiz-crm-b2b-batch-deploy` vs B2B `dev-gongbiz-batch-jdk17` vs Frontend `dev-gongbiz-crm-settlement-batch` 확인 |
| "admin 배포" | B2B `dev-crm-admin-jdk17` |
| "notification 배포" | B2B `dev-gongbiz-notification-monorepo` |
| "sso 배포" | B2C `dev-gongbiz-sso-deploy` |

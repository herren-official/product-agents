---
name: b2c-backend-cloudwatch
description: AWS CloudWatch 로그 조회 skill. 로그 검색, Insights 쿼리, 실시간 tail, 트러블슈팅을 지원합니다. CloudWatch, 로그, 에러 조회, 슬로우쿼리, 배치 상태 확인 등의 요청에 사용합니다.
---

# CloudWatch Log Skill

CloudWatch 로그를 조회하는 Claude Code skill입니다.

## AWS 인증 처리

모든 CloudWatch 명령 실행 전에 반드시 인증 상태를 먼저 확인합니다.

### 인증 확인 절차

1. 아래 명령으로 현재 세션 유효성을 확인합니다:
```bash
aws sts get-caller-identity --region ap-northeast-2 2>&1
```

2. **성공 시**: 바로 요청된 작업을 진행합니다.

3. **실패 시** (ExpiredToken, AccessDenied 등): 사용자에게 MFA 코드를 요청합니다.
   - "MFA 코드를 알려주세요." 라고 질문합니다.
   - 사용자가 6자리 코드를 제공하면 아래 명령을 실행합니다:
```bash
aws sts get-session-token \
  --serial-number arn:aws:iam::248704842720:mfa/nicky \
  --token-code {MFA_CODE} \
  --duration-seconds 3600 \
  --region ap-northeast-2
```
   - 반환된 Credentials를 환경변수로 설정합니다:
```bash
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."
```
   - 이후 모든 aws 명령에 이 환경변수를 포함합니다.

**중요**: 모든 aws CLI 명령에 `--region ap-northeast-2`를 포함합니다.

## 로그 그룹 Alias 매핑

사용자가 alias를 사용하면 아래 매핑에서 실제 로그 그룹 이름으로 변환합니다.
사용자가 전체 경로를 직접 입력해도 그대로 사용합니다.

### ECS 서비스

| Alias | 로그 그룹 |
|-------|----------|
| `prod-ecs-b2b-api` | `/ecs/prod-ecs-td-gongbiz-crm-b2b-api` |
| `prod-ecs-b2b-batch` | `/ecs/prod-ecs-td-gongbiz-crm-b2b-batch` |
| `prod-ecs-b2b-consumer` | `/ecs/prod-td-gongbiz-crm-b2b-consumer` |
| `prod-ecs-b2c-api` | `/ecs/prod-ecs-td-gongbiz-b2c-api` |
| `prod-ecs-b2c-front` | `/ecs/prod-ecs-td-gongbiz-b2c-front` |
| `prod-ecs-b2b-front-web` | `/ecs/prod-gongbiz-b2b-crm-front-web/application` |
| `prod-ecs-b2b-front-web-nginx` | `/ecs/prod-gongbiz-b2b-crm-front-web/nginx` |
| `prod-ecs-b2b-front-webview` | `/ecs/prod-gongbiz-b2b-crm-front-webview/application` |
| `prod-ecs-b2b-front-webview-nginx` | `/ecs/prod-gongbiz-b2b-crm-front-webview/nginx` |
| `prod-ecs-notification` | `/ecs/prod-gongbiz-notification-orchestrator` |
| `prod-ecs-sso` | `/ecs/prod-ecs-td-gongbiz-sso-keycloak` |
| `prod-ecs-sso-green` | `/ecs/prod-ecs-td-gongbiz-sso-keycloak-green` |
| `prod-ecs-settlement` | `/ecs/prod-ecs-td-gongbiz-settlement-batch` |
| `prod-ecs-grafana` | `/ecs/prod-ecs-td-gongbiz-grafana` |
| `prod-ecs-prometheus` | `/ecs/prod-ecs-td-gongbiz-prometheus` |
| `prod-ecs-push-gateway` | `/ecs/prod-ecs-td-gongbiz-push-gateway` |
| `dev-ecs-b2b-api` | `/ecs/dev-ecs-td-gongbiz-crm-b2b-api` |
| `dev-ecs-b2b-batch` | `/ecs/dev-ecs-td-gongbiz-crm-b2b-batch` |
| `dev-ecs-b2b-consumer` | `/ecs/dev-td-gongbiz-crm-b2b-consumer` |
| `dev-ecs-b2c-api` | `/ecs/dev-ecs-td-gongbiz-b2c-api` |
| `dev-ecs-b2c-front` | `/ecs/dev-ecs-td-gongbiz-b2c-front` |
| `dev-ecs-notification` | `/ecs/dev-gongbiz-notification-orchestrator` |
| `dev-ecs-sso` | `/ecs/dev-ecs-td-gongbiz-sso-keycloak` |
| `dev-ecs-settlement` | `/ecs/dev-ecs-td-gongbiz-settlement-batch` |
| `dev1-ecs-b2b-front` | `/ecs/dev1-gongbiz-crm-b2b-front/application` |
| `dev1-ecs-b2b-front-nginx` | `/ecs/dev1-gongbiz-crm-b2b-front/nginx` |
| `dev2-ecs-b2b-front` | `/ecs/dev2-gongbiz-crm-b2b-front/application` |
| `dev2-ecs-b2b-front-nginx` | `/ecs/dev2-gongbiz-crm-b2b-front/nginx` |
| `dev4-ecs-b2b-front` | `/ecs/dev4-gongbiz-crm-b2b-front/application` |
| `dev4-ecs-b2b-front-nginx` | `/ecs/dev4-gongbiz-crm-b2b-front/nginx` |
| `dev5-ecs-b2b-front` | `/ecs/dev5-gongbiz-crm-b2b-front/application` |
| `dev5-ecs-b2b-front-nginx` | `/ecs/dev5-gongbiz-crm-b2b-front/nginx` |
| `dev6-ecs-b2b-front` | `/ecs/dev6-gongbiz-crm-b2b-front/application` |
| `dev6-ecs-b2b-front-nginx` | `/ecs/dev6-gongbiz-crm-b2b-front/nginx` |
| `dev8-ecs-b2b-front` | `/ecs/dev8-gongbiz-crm-b2b-front/application` |
| `dev8-ecs-b2b-front-nginx` | `/ecs/dev8-gongbiz-crm-b2b-front/nginx` |
| `qa-ecs-b2b-api` | `/ecs/qa-ecs-td-gongbiz-crm-b2b-api` |
| `qa-ecs-b2c-api` | `/ecs/qa-ecs-td-gongbiz-b2c-api` |
| `qa-ecs-b2c-front` | `/ecs/qa-ecs-td-gongbiz-b2c-front` |

### Elastic Beanstalk

| Alias | 로그 그룹 |
|-------|----------|
| `prod-eb-b2b-app` | `/aws/elasticbeanstalk/prod-eb-gongbiz-crm-b2b-app/var/log/gongbiz/application.log` |
| `prod-eb-b2b-app-catalina` | `/aws/elasticbeanstalk/prod-eb-gongbiz-crm-b2b-app/var/log/catalina.out` |
| `prod-eb-b2b-web` | `/aws/elasticbeanstalk/prod-eb-gongbiz-crm-b2b-web/var/log/gongbiz/application.log` |
| `prod-eb-b2b-web-catalina` | `/aws/elasticbeanstalk/prod-eb-gongbiz-crm-b2b-web/var/log/catalina.out` |
| `prod-eb-crawl` | `/aws/elasticbeanstalk/prod-eb-gongbiz-insta-crawl-server/var/log/tomcat/catalina.out` |
| `dev1-eb-b2b` | `/aws/elasticbeanstalk/dev1-eb-gongbiz-crm-b2b-server/var/log/gongbiz/application.log` |
| `dev2-eb-b2b` | `/aws/elasticbeanstalk/dev2-eb-gongbiz-crm-b2b-server/var/log/gongbiz/application.log` |
| `dev3-eb-b2b` | `/aws/elasticbeanstalk/dev3-eb-gongbiz-crm-b2b-server/var/log/gongbiz/application.log` |
| `dev4-eb-b2b` | `/aws/elasticbeanstalk/dev4-eb-gongbiz-crm-b2b-server/var/log/gongbiz/application.log` |
| `dev5-eb-b2b` | `/aws/elasticbeanstalk/dev5-eb-gongbiz-crm-b2b-server/var/log/gongbiz/application.log` |
| `dev6-eb-b2b` | `/aws/elasticbeanstalk/dev6-eb-gongbiz-crm-b2b-server/var/log/gongbiz/application.log` |
| `dev-eb-crawl` | `/aws/elasticbeanstalk/dev-gongbiz-insta-crawl-server-jdk17/var/log/web.stdout.log` |

### RDS

| Alias | 로그 그룹 |
|-------|----------|
| `prod-db-slowquery` | `/aws/rds/instance/prod-rds-gongbiz/slowquery` |
| `prod-db-error` | `/aws/rds/instance/prod-rds-gongbiz/error` |
| `prod-db-audit` | `/aws/rds/instance/prod-rds-gongbiz/audit` |
| `prod-db-replica-slowquery` | `/aws/rds/instance/prod-rds-gongbiz-replica/slowquery` |
| `prod-db-replica-error` | `/aws/rds/instance/prod-rds-gongbiz-replica/error` |
| `prod-db-sso-error` | `/aws/rds/instance/prod-rds-gongbiz-sso/error` |
| `prod-db-sso-slowquery` | `/aws/rds/instance/prod-rds-gongbiz-sso/slowquery` |
| `prod-db-hejabox-error` | `/aws/rds/instance/prod-rds-herren-hejabox/error` |
| `dev-db-slowquery` | `/aws/rds/instance/dev-rds-gongbiz-crm/slowquery` |
| `dev-db-error` | `/aws/rds/instance/dev-rds-gongbiz-crm/error` |
| `dev-db-audit` | `/aws/rds/instance/dev-rds-gongbiz-crm/audit` |
| `dev-db-keycloak-error` | `/aws/rds/instance/dev-rds-gongbiz-keycloak-mariadb/error` |
| `dev-db-keycloak-slowquery` | `/aws/rds/instance/dev-rds-gongbiz-keycloak-mariadb/slowquery` |

### Kafka Connect

| Alias | 로그 그룹 |
|-------|----------|
| `prod-kafka-cdc` | `/aws/kafkaconnect/prod-msk-connector-gongbiz-crm-cdc` |
| `dev-kafka-cdc` | `/aws/kafkaconnect/dev-msk-connector-gongbiz-crm-cdc` |

### Lambda (주요)

| Alias | 로그 그룹 |
|-------|----------|
| `prod-lambda-batch-extractor` | `/aws/lambda/prod-lambda-gongbiz-crm-admin-batch-extractor` |
| `prod-lambda-batch-validator` | `/aws/lambda/prod-lambda-gongbiz-crm-admin-batch-validator` |
| `prod-lambda-image-resize` | `/aws/lambda/prod-lambda-gongbiz-crm-image-resize` |
| `prod-lambda-batch-health` | `/aws/lambda/prod-lambda-gongbiz-crm-batch-health-check` |
| `prod-lambda-sqs-b2b-alimtalk` | `/aws/lambda/prod-lambda-sqs-gongbiz-b2b-alimtalk` |
| `prod-lambda-sqs-b2c-alimtalk` | `/aws/lambda/prod-lambda-sqs-gongbiz-b2c-alimtalk` |
| `prod-lambda-deploy-alarm` | `/aws/lambda/prod-lambda-gongbiz-front-deploy-alarm` |
| `prod-lambda-send-sms` | `/aws/lambda/gongbiz-send-sms` |
| `prod-lambda-alimtalk-fail` | `/aws/lambda/prod-slack-notify-alimtalk-fail` |
| `dev-lambda-batch-extractor` | `/aws/lambda/dev-lambda-gongbiz-crm-admin-batch-extractor` |
| `dev-lambda-batch-validator` | `/aws/lambda/dev-lambda-gongbiz-crm-admin-batch-validator` |
| `dev-lambda-image-resize` | `/aws/lambda/dev-lambda-gongbiz-crm-image-resize` |
| `dev-lambda-send-sms` | `/aws/lambda/dev-gongbiz-send-sms` |
| `dev-lambda-alimtalk-fail` | `/aws/lambda/dev-slack-notify-alimtalk-fail` |

### 기타

| Alias | 로그 그룹 |
|-------|----------|
| `prod-alb-b2c-front` | `/aws/alb/prod-gongbiz-b2c-front` |
| `prod-notification` | `prod-gongbiz-notification` |
| `prod-notification-bt` | `prod-gongbiz-notification-bt` |
| `dev-notification` | `dev-gongbiz-notification` |
| `dev-notification-bat` | `dev-gongbiz-notification-bat` |
| `prod-bedrock` | `prod-bedrock-gongbiz` |
| `prod-trail` | `prod-cw-gongbiz-trail-logs` |
| `prod-cloudfront` | `/aws/cloudfront/LambdaEdge/EE4L7FLJ97OXN` |
| `crm-front-log` | `crm-front-log` |
| `crm-front-prod-error` | `crm-front-production-error` |
| `crm-front-prod-error-webview` | `crm-front-production-error-webview` |
| `staging-waf` | `gongbiz-b2b-staging-waf-logs` |

## 기능

### 1. 키워드 검색 (filter-log-events)

특정 로그 그룹에서 키워드로 로그를 검색합니다.

```bash
aws logs filter-log-events \
  --log-group-name "{LOG_GROUP}" \
  --filter-pattern "{KEYWORD}" \
  --start-time {START_EPOCH_MS} \
  --end-time {END_EPOCH_MS} \
  --region ap-northeast-2 \
  --output json
```

- 시간 미지정 시 기본값: 최근 1시간
- `--filter-pattern` 문법:
  - 단순 키워드: `"ERROR"`
  - AND 조건: `"ERROR timeout"`
  - OR 조건은 지원하지 않으므로 별도 쿼리로 실행
  - 특정 JSON 필드: `{ $.level = "ERROR" }`
- 결과가 많으면 `--limit`으로 제한합니다 (기본 50).
- `nextToken`이 반환되면 사용자에게 더 볼지 물어봅니다.

### 2. CloudWatch Insights 쿼리

복잡한 쿼리는 CloudWatch Logs Insights를 사용합니다.

**쿼리 시작:**
```bash
aws logs start-query \
  --log-group-name "{LOG_GROUP}" \
  --start-time {START_EPOCH} \
  --end-time {END_EPOCH} \
  --query-string '{QUERY}' \
  --region ap-northeast-2
```

**결과 조회 (queryId 사용):**
```bash
aws logs get-query-results --query-id "{QUERY_ID}" --region ap-northeast-2
```

- `status`가 `Running`이면 2~3초 후 재조회합니다.
- `Complete`가 되면 결과를 보기 좋게 정리하여 표시합니다.

**자주 쓰는 Insights 쿼리 예시:**
```
# 에러 로그 검색
fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 50

# 특정 키워드 + 시간순
fields @timestamp, @message | filter @message like /키워드/ | sort @timestamp desc | limit 100

# 에러 빈도 집계 (5분 단위)
fields @timestamp, @message | filter @message like /ERROR/ | stats count() as errorCount by bin(5m)

# 특정 HTTP 상태코드
fields @timestamp, @message | filter @message like /status=5\d{2}/ | sort @timestamp desc | limit 50

# 슬로우쿼리 분석
fields @timestamp, @message | filter @message like /slow/ | sort @timestamp desc | limit 50
```

### 3. 실시간 Tail (라이브 로그)

```bash
aws logs tail "{LOG_GROUP}" --follow --since 5m --region ap-northeast-2
```

- `--since`: 시작 시점 (예: `5m`, `1h`, `2024-01-01T00:00:00`)
- `--follow`: 실시간 스트리밍 (Ctrl+C로 중단)
- `--filter-pattern`을 추가하여 특정 패턴만 볼 수 있습니다.

**주의**: `--follow` 사용 시 Bash 명령의 timeout을 충분히 설정합니다 (최대 600000ms). 사용자에게 "Ctrl+C 또는 중지 요청으로 종료할 수 있습니다"라고 안내합니다.

### 4. 로그 그룹 목록 조회

```bash
aws logs describe-log-groups --region ap-northeast-2 --query 'logGroups[].logGroupName' --output text | tr '\t' '\n' | sort
```

## 시간 범위 처리

사용자가 시간을 지정하는 다양한 방식을 지원합니다:

| 입력 예시 | 해석 |
|----------|------|
| `최근 30분` / `30분 전부터` | now - 30min ~ now |
| `최근 2시간` | now - 2h ~ now |
| `오늘` | 오늘 00:00 KST ~ now |
| `어제` | 어제 00:00 KST ~ 어제 23:59:59 KST |
| `4월 15일 14시~16시` | 해당 시간 KST → epoch 변환 |
| 미지정 | 최근 1시간 |

**epoch 변환** (KST → UTC → epoch):
```bash
# macOS
date -j -f "%Y-%m-%d %H:%M:%S" "2026-04-16 14:00:00" "+%s"
# 또는 GNU date가 설치된 경우
gdate -d "2026-04-16 14:00:00 KST" "+%s"
```

`filter-log-events`는 밀리초 epoch, `start-query`는 초 단위 epoch을 사용합니다.

## 로그 패턴 및 추적 전략

### 로그 포맷

이 시스템은 Log4j2 / Logback을 사용하며, 주요 로그 포맷은 다음과 같습니다:

```
2026-04-16 14:30:15.123  INFO 1 [main] [prod] [reqId=abc-123] [tid=def-456] [prod-host-1] c.n.c.v.s.SomeService  [mem:...]  실제 메시지
```

### MDC 추적 필드

| 필드 | 설명 | Insights 쿼리 예시 |
|------|------|-------------------|
| `traceId` (tid) | 요청 단위 UUID, 전 서비스 공유 | `filter @message like /tid=abc-def-123/` |
| `requestId` (reqId) | HTTP 요청 ID (X-RequestID 헤더) | `filter @message like /reqId=abc-def-123/` |
| `userId` | 인증된 사용자 ID | `filter @message like /UserId: 12345/` |
| `memberId` | 회원 ID (B2B API 인터셉터) | `filter @message like /memberId: 12345/` |
| `shopNo` | 매장 번호 (결제/정산) | `filter @message like /shopNo: 12345/` |

### AOP 요청 로깅 패턴

모든 API 요청은 LogAspect에 의해 다음 형태로 기록됩니다:

```
REQUEST ::: Request URL: /api/v1/some/path, Execution Method: methodName, Headers: {...}, UserId: 12345, Parameters: {...}
```

**따라서 특정 사용자의 모든 요청을 추적하려면:**
```
fields @timestamp, @message | filter @message like /UserId: 12345/ | filter @message like /REQUEST/ | sort @timestamp desc
```

### 트러블슈팅 시나리오별 검색 전략

#### 1. 로그인/회원가입 문제 (B2C)

로그인 실패 시 userId가 없을 수 있으므로 다음 순서로 조사합니다:

**대상 로그 그룹**: `prod-ecs-b2c-api` (또는 dev)

```
# 1단계: 시간대 + OAuth 엔드포인트로 범위 좁히기
fields @timestamp, @message
| filter @message like /\/oauth/
| filter @message like /REQUEST/
| sort @timestamp desc | limit 100

# 2단계: 에러/예외 확인
fields @timestamp, @message
| filter @message like /auth/ or @message like /oauth/ or @message like /sign/
| filter @message like /ERROR/ or @message like /Exception/
| sort @timestamp desc | limit 50

# 3단계: 특정 시간대의 모든 에러 (traceId로 연결)
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc | limit 100
```

전화번호, 이메일 등 사용자 식별 정보가 있으면 Parameters에서 검색합니다.

#### 2. 결제/정산 문제 (B2B)

**대상 로그 그룹**: `prod-ecs-b2b-api`, `prod-ecs-settlement`

```
# shopNo로 결제 관련 로그 추적
fields @timestamp, @message
| filter @message like /shopNo: {SHOP_NO}/
| sort @timestamp desc | limit 100

# KIS 서브몰 등록/실패
fields @timestamp, @message
| filter @message like /서브몰/ or @message like /KIS/
| sort @timestamp desc | limit 50

# 정산 에러
fields @timestamp, @message
| filter @message like /정산/ and (@message like /ERROR/ or @message like /실패/)
| sort @timestamp desc | limit 50
```

#### 3. 알림톡 발송 실패

**대상 로그 그룹**: `prod-notification`, `prod-notification-bt`, `prod-lambda-sqs-b2b-alimtalk`, `prod-lambda-sqs-b2c-alimtalk`, `prod-lambda-alimtalk-fail`

```
# BizTalk API 에러
fields @timestamp, @message
| filter @message like /BizTalk/ and @message like /Error/
| sort @timestamp desc | limit 50

# 발송 결과 요약 (배치 로그)
fields @timestamp, @message
| filter @message like /success/ or @message like /fail/
| filter @message like /count/
| sort @timestamp desc | limit 50
```

#### 4. 배치 작업 실패 (B2B Batch)

**대상 로그 그룹**: `prod-ecs-b2b-batch`

```
# 배치 실행 결과
fields @timestamp, @message
| filter @message like /Job 실행/ or @message like /Scheduler/
| sort @timestamp desc | limit 50

# 배치 에러
fields @timestamp, @message
| filter @message like /ERROR/ or @message like /실패/
| sort @timestamp desc | limit 50
```

#### 5. 슬로우쿼리 분석

**대상 로그 그룹**: `prod-db-slowquery`

```
fields @timestamp, @message
| sort @timestamp desc | limit 50
```

#### 6. traceId로 요청 전체 흐름 추적

하나의 traceId를 알면 여러 로그 그룹을 동시에 검색하여 전체 요청 흐름을 추적합니다:

```bash
# 여러 로그 그룹에서 동시에 traceId 검색 (Insights)
aws logs start-query \
  --log-group-names "/ecs/prod-ecs-td-gongbiz-crm-b2b-api" "/ecs/prod-ecs-td-gongbiz-crm-b2b-batch" "/ecs/prod-td-gongbiz-crm-b2b-consumer" \
  --start-time {START} --end-time {END} \
  --query-string 'fields @timestamp, @message | filter @message like /tid={TRACE_ID}/ | sort @timestamp asc' \
  --region ap-northeast-2
```

### 다중 로그 그룹 검색

사용자가 쉼표로 여러 alias를 나열하면 `--log-group-names`(복수)를 사용하여 동시 검색합니다:

```bash
# "prod-ecs-b2b-api, prod-ecs-b2c-api에서 에러 검색해줘"
aws logs start-query \
  --log-group-names "/ecs/prod-ecs-td-gongbiz-crm-b2b-api" "/ecs/prod-ecs-td-gongbiz-b2c-api" \
  --start-time {START} --end-time {END} \
  --query-string 'fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 100' \
  --region ap-northeast-2
```

**참고**: `filter-log-events`는 단일 로그 그룹만 지원하므로, 다중 로그 그룹 검색 시 반드시 Insights(`start-query`)를 사용합니다.

## 출력 형식

- 로그 결과는 **타임스탬프(KST)**와 **메시지**를 깔끔하게 정리하여 보여줍니다.
- JSON 형태의 로그는 주요 필드를 추출하여 가독성 있게 표시합니다.
- 에러 로그는 스택트레이스가 있으면 함께 표시합니다.
- 결과가 길면 핵심 내용을 요약하고, 필요시 전체 내용을 보여줍니다.

## 사용 예시

사용자가 이런 식으로 요청할 수 있습니다:

**기본 검색:**
- "prod-ecs-b2b-api에서 최근 30분 ERROR 로그 보여줘"
- "dev3-eb-b2b 로그에서 NullPointerException 검색해줘"
- "prod-db-slowquery 오늘 슬로우쿼리 보여줘"

**실시간 & 분석:**
- "prod-ecs-b2c-api 실시간 로그 틀어줘"
- "prod-ecs-b2b-batch에서 어제 오후 2시부터 3시 사이 에러 분석해줘"
- "prod-ecs-b2b-api에서 최근 1시간 에러 빈도를 5분 단위로 보여줘" (→ Insights 사용)

**다중 로그 그룹:**
- "prod-ecs-b2b-api, prod-ecs-b2c-api에서 로그인 에러 검색해줘"
- "prod-ecs-b2b-api, prod-ecs-b2b-batch, prod-ecs-b2b-consumer에서 traceId abc-123으로 추적해줘"

**트러블슈팅:**
- "고객이 로그인이 안된다고 해요, prod-ecs-b2c-api에서 오후 2시쯤 OAuth 에러 확인해줘"
- "shopNo 12345 결제 문제 조사해줘" (→ prod-ecs-b2b-api에서 shopNo로 검색)
- "알림톡 발송 실패 건 확인해줘" (→ notification 관련 로그 그룹 자동 검색)
- "오늘 배치 정상 실행됐는지 확인해줘" (→ prod-ecs-b2b-batch에서 Job 실행 결과 검색)

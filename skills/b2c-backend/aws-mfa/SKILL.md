---
name: b2c-backend-aws-mfa
description: AWS MFA 세션 토큰 발급 후 ~/.aws/credentials 의 [default] 프로파일을 갱신합니다. UnauthorizedOperation (MFA-policy) 에러가 나거나, Terraform/CLI 작업 전 MFA 세션이 필요할 때 사용합니다. "MFA 갱신", "MFA 받아줘", "MFA 세션 만들어줘" 같은 요청에도 사용합니다.
---

# AWS MFA Session Refresh

MFA 정책이 걸린 AWS 계정(`248704842720`)에서 CLI/Terraform 작업 시 필요한 임시 세션 토큰을 받아 `~/.aws/credentials` 의 `[default]` 프로파일에 **파일 단위로 영구 저장**합니다.

cloudwatch skill 의 환경변수 방식(쉘 세션에서만 유효)과 달리, 이 skill 은 credentials 파일을 직접 수정하여 **Terraform / 별도 쉘 / IDE 에서도** 인증이 유지되도록 합니다.

## When to use

- `UnauthorizedOperation` 에러 메시지에 `MFA-policy` 가 포함된 경우
- `tofu apply`, `tofu plan`, `aws ec2/ssm/iam` 명령 실행 전
- 사용자가 "MFA 갱신", "MFA 받아줘", "MFA 세션 만들어줘", "세션 만료됐어" 등으로 요청

## Constants

| 키 | 값 |
|---|---|
| MFA 디바이스 ARN | `arn:aws:iam::248704842720:mfa/nicky` |
| AWS 계정 | `248704842720` |
| 리전 | `ap-northeast-2` |
| 기본 세션 유효시간 | 43200초 (12시간) |
| Base 프로파일 이름 | `nicky-base` (long-lived credential 보관용) |
| 세션 기록 프로파일 | `default` |

## Procedure

### Step 1. 현재 세션 유효성 먼저 확인

```bash
aws sts get-caller-identity --region ap-northeast-2 2>&1
```

- **성공 + UserId 반환**: 세션 유효. 갱신 필요 없음. "이미 유효한 세션이 있습니다" 라고 알리고 종료.
- **`ExpiredToken` / `InvalidClientTokenId`** 등 실패: Step 2 로 진행.

### Step 2. Base 프로파일 확인/준비

`~/.aws/credentials` 를 읽는다.

- `[nicky-base]` 섹션이 **존재하면**: 그대로 사용. Step 3 로.
- `[nicky-base]` 가 **없으면**:
  - `[default]` 에 `aws_session_token` 이 **없을 때** (long-lived): `[default]` 를 복제해서 `[nicky-base]` 섹션으로 추가한다.
  - `[default]` 에 `aws_session_token` 이 **있을 때** (이미 만료된 세션만 남은 상태): base 를 복구할 방법이 없으므로 사용자에게 `[nicky-base]` 를 수동 등록해달라 요청 후 종료.

Python 으로 ini 파싱/수정 (가장 안전):
```bash
python3 <<'EOF'
import configparser, shutil, os
p = os.path.expanduser('~/.aws/credentials')
cfg = configparser.RawConfigParser()
cfg.read(p)
if 'nicky-base' not in cfg:
    if 'aws_session_token' in cfg['default']:
        raise SystemExit('[default] 가 이미 세션이고 nicky-base 없음 — 수동 복구 필요')
    cfg['nicky-base'] = dict(cfg['default'])
    with open(p, 'w') as f:
        cfg.write(f)
    print('nicky-base 생성됨')
else:
    print('nicky-base 존재')
EOF
```

### Step 3. MFA 코드 요청

아직 받지 않았다면 사용자에게 요청:
> "MFA 코드 6자리 알려주세요. (30초 안에 사용 필요)"

### Step 4. 세션 토큰 발급

`[nicky-base]` 프로파일로 STS 호출 (이 호출 자체는 MFA 세션 불필요):

```bash
aws --profile nicky-base sts get-session-token \
  --serial-number arn:aws:iam::248704842720:mfa/nicky \
  --token-code {MFA_CODE} \
  --duration-seconds 43200 \
  --region ap-northeast-2
```

출력 JSON 예:
```json
{
  "Credentials": {
    "AccessKeyId": "ASIA...",
    "SecretAccessKey": "...",
    "SessionToken": "...",
    "Expiration": "2026-04-22T02:42:12+00:00"
  }
}
```

### Step 5. `[default]` 에 세션 기록

Python 으로 덮어쓰기 (ini 라인 끝 공백/주석 보존):

```bash
python3 <<EOF
import configparser, os, json, subprocess
p = os.path.expanduser('~/.aws/credentials')
creds = json.loads('''$(<Step4 출력 JSON 파일 내용)''')['Credentials']
cfg = configparser.RawConfigParser()
cfg.read(p)
cfg['default']['aws_access_key_id']     = creds['AccessKeyId']
cfg['default']['aws_secret_access_key'] = creds['SecretAccessKey']
cfg['default']['aws_session_token']     = creds['SessionToken']
with open(p, 'w') as f:
    cfg.write(f)
print(f"default 갱신됨. 만료: {creds['Expiration']}")
EOF
```

실무 팁: Step 4 의 JSON 을 tmp 파일로 저장한 뒤 Step 5 스크립트가 그 파일을 읽게 하면 heredoc 변수 치환 이슈 피할 수 있다:
```bash
aws --profile nicky-base sts get-session-token ... --output json > /tmp/mfa-session.json
python3 - <<'EOF'
import configparser, os, json
p = os.path.expanduser('~/.aws/credentials')
creds = json.load(open('/tmp/mfa-session.json'))['Credentials']
cfg = configparser.RawConfigParser()
cfg.read(p)
cfg['default']['aws_access_key_id']     = creds['AccessKeyId']
cfg['default']['aws_secret_access_key'] = creds['SecretAccessKey']
cfg['default']['aws_session_token']     = creds['SessionToken']
with open(p, 'w') as f:
    cfg.write(f)
print(f"default 갱신됨. 만료: {creds['Expiration']}")
EOF
rm /tmp/mfa-session.json
```

### Step 6. 검증

```bash
aws sts get-caller-identity --region ap-northeast-2
```

성공 시 만료 시각을 사용자에게 안내:
> "MFA 세션 갱신 완료. 만료: 2026-04-22 14:42:12 KST (12시간 후)"

## Error Handling

| 에러 | 원인 | 대응 |
|---|---|---|
| `MultiFactorAuthentication failed with invalid MFA one time pass code` | 코드 오타 또는 30초 지나 만료됨 | 새 코드 요청 |
| `[default] 가 이미 세션이고 nicky-base 없음` | Base credential 소실 | 사용자에게 AWS 콘솔에서 새 Access Key 발급 후 `[nicky-base]` 수동 등록 요청 |
| `aws: command not found` | AWS CLI 미설치 | `brew install awscli` 안내 |
| 403 `AccessDenied` 여전 | MFA 없이도 금지된 작업 | MFA 문제 아님. IAM 권한 점검 |

## Notes

- 세션 토큰은 **최대 36시간**(STS 기본 12시간). `--duration-seconds 129600` (36시간) 가능.
- `[default]` 프로파일을 공유 사용하는 다른 서비스(AWS SDK, boto3 등)도 자동으로 세션 credential 을 쓴다.
- `~/.aws/credentials` 파일은 권한 `0600` 유지 (configparser 가 덮어써도 유지되지만 혹시 만져졌다면 `chmod 600 ~/.aws/credentials`).
- 만료 시각 이후에는 다시 Step 3 부터 반복.

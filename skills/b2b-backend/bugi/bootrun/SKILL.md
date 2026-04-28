---
name: b2b-backend-bootrun
description: 워크트리 또는 메인 작업 디렉토리에서 gongbiz-crm-b2b-backend 로컬 서버를 실행한다. "bootrun", "로컬 서버 실행", "백엔드 서버 띄워줘" 요청 시 트리거.
---

# bootrun

워크트리에서 gongbiz-crm-b2b-backend 로컬 서버를 실행한다.

## 사전 준비

1. gitignore된 파일을 워크트리에 심볼릭 링크:
```bash
ln -sf <메인작업트리>/gongbiz-crm-b2b-backend/src/main/resources/application-local.properties <현재워크트리>/gongbiz-crm-b2b-backend/src/main/resources/application-local.properties
ln -sf <메인작업트리>/.env.local <현재워크트리>/.env.local
```

2. 외부 Redis가 떠있으면 종료 (embedded Redis와 포트 충돌):
```bash
redis-cli shutdown 2>/dev/null; brew services stop redis 2>/dev/null
```

3. 8080 포트 사용 중이면 종료:
```bash
lsof -ti:8080 | xargs kill -9 2>/dev/null
```

## 서버 실행

`.env.local`의 키에 `-`가 포함되어 shell source가 안 됨. Python으로 환경변수를 주입해야 한다.

```bash
python3 -c "
import subprocess, os
env = os.environ.copy()
with open('.env.local') as f:
    for line in f:
        line = line.strip()
        if line and not line.startswith('#') and '=' in line:
            key, val = line.split('=', 1)
            env[key] = val
proc = subprocess.Popen(
    ['./gradlew', ':gongbiz-crm-b2b-backend:bootRun', '--args=--spring.profiles.active=local'],
    env=env,
    stdout=open('/tmp/bootrun.log', 'w'),
    stderr=subprocess.STDOUT
)
print(f'PID: {proc.pid}')
"
```

## 기동 확인

서버 기동까지 1~2분 소요. 상태 코드가 000이 아니면 서버가 뜬 것:
```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/
```

## 실패 시 로그 확인
```bash
grep -E "FAIL|Error|Started" /tmp/bootrun.log | tail -5
```

## 요청 내용

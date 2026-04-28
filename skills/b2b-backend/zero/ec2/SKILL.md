---
name: b2b-backend-ec2
description: EC2 서버 SSH 접속하여 로그 확인
argument-hint: <batch> [tail|grep PATTERN|log YYYY-MM-DD]
---

EC2 서버에 SSH 접속하여 로그를 확인한다.

## 서버 목록

| 서버 | 호스트 | 유저 | PEM |
|---|---|---|---|
| crm-batch (운영) | 43.200.89.7 | ubuntu | ~/herren-repo/AWS_PEM_FILES/gongbiz-b2b/bada-key.pem |
| jenkins | 52.78.54.58 | ubuntu | ~/herren-repo/AWS_PEM_FILES/gongbiz-b2b/bada-key.pem |
| dev3-eb | 3.34.178.57 | ec2-user | ~/herren-repo/AWS_PEM_FILES/gongbiz-b2b/bada-key.pem |

## 사용법

인자가 없으면 서버 목록을 보여주고 선택을 요청한다.

### 인자 형식
- `/ec2 batch` — crm-batch 서버 접속, 오늘 로그 tail 100줄
- `/ec2 batch tail` — 실시간 로그 (tail -f, 10초 타임아웃)
- `/ec2 batch grep ERROR` — 오늘 로그에서 ERROR 검색
- `/ec2 batch log 2026-03-31` — 특정 날짜 로그 확인

## 실행 절차

1. 인자에서 서버명과 명령을 파싱한다.
2. 서버 목록에서 호스트/유저/PEM 경로를 매칭한다.
3. SSH 접속하여 명령을 실행한다.

### SSH 기본 옵션
```
ssh -i {PEM} -o StrictHostKeyChecking=no -o ConnectTimeout=10 {유저}@{호스트}
```

### 로그 경로 패턴
- crm-batch: `/var/log/tomcat8/NailShopAdmin.{날짜}.log` (날짜 형식: YYYY-MM-DD)

### 기본 동작 (인자: 서버명만)
오늘 날짜 로그 파일의 마지막 100줄을 출력한다.

### tail 모드
`tail -f`로 실시간 로그를 보여준다. Bash timeout 10초로 제한한다.

### grep 모드
오늘 로그에서 지정된 패턴을 검색한다. 결과가 많으면 마지막 50줄만 보여준다.

### log 날짜 모드
지정된 날짜의 로그 파일 마지막 100줄을 출력한다.

## 새 서버 추가

서버 목록 테이블에 행을 추가하면 된다. 접속 전 PEM 파일 존재 여부를 확인한다.

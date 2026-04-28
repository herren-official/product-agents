---
name: b2b-backend-troubleshoot
description: |
  /api-test-plan 또는 /monitor 실행 중 발생하는 에러를 진단하고 해결 가이드를 제공한다.
  다음 상황에서 사용할 것:
  - /api-test-plan 또는 /monitor 실행 중 에러가 발생했을 때
  - AWS CLI, SSH, git 관련 에러 해결이 필요할 때
  다음 상황에서는 사용하지 않을 것:
  - 정상적으로 플랜 생성/모니터링이 진행되고 있을 때
allowed-tools: Read, Bash
user-invocable: true
---

$ARGUMENTS 에서 에러 상황을 받아 진단하고 해결 가이드를 제공한다.

## 에러 유형별 진단

### 1. git diff 실패
**증상**: `/api-test-plan` 실행 시 "fatal: bad revision" 또는 브랜치를 찾을 수 없음
**진단 절차**:
1. `git branch -a | grep {브랜치명}` — 브랜치 존재 여부 확인
2. `git fetch origin` — 원격 브랜치 동기화
3. `git fetch origin develop` — develop 브랜치 확보
**해결**: 브랜치명 오타 확인, `git fetch origin` 실행 후 재시도

### 2. AWS CLI 인증 실패
**증상**: "ExpiredTokenException", "InvalidIdentityToken", "Unable to locate credentials"
**진단 절차**:
1. `aws sts get-caller-identity --profile mfa` — 현재 인증 상태 확인
2. `~/bin/aws-mfa {OTP}` — MFA 수동 갱신 (OTP는 사용자에게 질문)
**해결**: `~/bin/aws-mfa {OTP}` 실행 후 재시도. 모든 aws 명령에 `--profile mfa` 필수. `~/.aws/credentials` 파일의 만료 시간 확인

### 3. 로그 그룹 미존재
**증상**: "ResourceNotFoundException" 또는 "The specified log group does not exist"
**진단 절차**:
1. `aws logs describe-log-groups --log-group-name-prefix "{로그그룹 앞부분}"` — 실제 로그 그룹명 확인
2. 메모리의 `reference_aws_module_infra_mapping.md`와 대조
**해결**: 로그 그룹명 오타 확인. 환경 번호(`{envNum}`) 치환이 올바른지 확인

### 4. SSH 접속 실패
**증상**: "Connection refused", "Connection timed out", "Permission denied"
**진단 절차**:
1. `ssh-list` — SSH config 호스트 목록 조회
2. `ssh -v {호스트}` — 상세 접속 로그 확인
3. VPN 연결 상태 확인
**해결**: VPN 연결 확인, SSH config의 호스트명 확인, ProxyJump/Bastion 설정 확인

### 5. ECS exec 실패
**증상**: ECS 컨테이너 접속 불가
**진단 절차**: 메모리의 `reference_session_manager_plugin.md` 참조
**해결**: AWS Session Manager Plugin 설치 확인

### 6. 키워드 0건 지속
**증상**: 모니터링 중 특정 키워드가 계속 0건
**진단 절차**:
1. 키워드가 실제 코드에 존재하는지 확인 (오타, 대소문자)
2. 해당 기능이 아직 배포되지 않았는지 확인
3. 올바른 환경(dev1/dev2/...)을 모니터링하고 있는지 확인
4. 로그 레벨이 DEBUG인데 운영 로그 레벨이 INFO인지 확인
**해결**: 키워드 수정 또는 배포 확인 후 재모니터링

### 7. 모듈 매핑 불가
**증상**: infra-mapper가 "매핑 불가"를 반환
**진단 절차**:
1. 해당 모듈이 `reference_aws_module_infra_mapping.md`에 등록되어 있는지 확인
2. 신규 모듈이면 인프라 담당자에게 로그 그룹 확인
**해결**: 매핑 테이블에 신규 모듈 추가 후 재실행

## 출력 형식
```
## 진단 결과
- 에러 유형: {유형}
- 원인: {원인}
- 해결 방법:
  1. {단계}
  2. {단계}
- 재시도 명령: `{명령어}`
```

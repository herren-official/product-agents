---
name: b2b-backend-review-transaction
description: git diff 기준으로 트랜잭션 관련 잠재적 문제를 분석한다. afterCommit + REQUIRED 조합, 외부 API in 트랜잭션, REQUIRES_NEW 남용 등 검출.
---

# 트랜잭션 패턴 리뷰

git diff로 변경된 파일을 기준으로 트랜잭션 관련 잠재적 문제를 분석한다.

## 실행 순서

### 1. 변경 파일 파악
`git diff --name-only HEAD` 또는 `git diff --name-only --cached`로 변경된 파일 목록을 가져온다.
변경 파일이 없으면 `git diff --name-only HEAD~1`로 최근 커밋 기준으로 분석한다.

### 2. 변경 파일 및 연관 파일 탐색
변경된 각 파일을 읽고, 아래 연관 파일을 추가로 탐색한다:
- 변경 파일에서 import하거나 호출하는 Service / Repository / Component
- 변경 파일을 호출하는 상위 호출부 (Grep으로 클래스명/메서드명 검색)
- 트랜잭션 콜백(afterCommit, afterCompletion 등)이 등록된 위치

### 3. 아래 패턴을 중점 검토

#### [A] afterCommit 안에서 @Transactional(REQUIRED) 호출
- `TransactionSynchronizationManager.registerSynchronization` 또는 `afterCommit()` 오버라이드 내부에서
  `@Transactional` (propagation 미지정 = REQUIRED) 메서드를 호출하는 경우를 찾는다.
- **왜 위험한가**: afterCommit 시점에는 외부 트랜잭션이 이미 커밋됐지만 ThreadLocal에 EntityManager가
  아직 남아있어, REQUIRED가 죽은 트랜잭션에 참여한다. 결과적으로 DB write(INSERT/UPDATE/DELETE)가
  커밋되지 않는다. 로그에는 성공으로 찍히지만 DB에는 반영되지 않는다.
- **올바른 해결**: `@Transactional(propagation = Propagation.REQUIRES_NEW)` 사용

#### [B] afterCommit 안에서 DB write 누락
- afterCommit 콜백 내부에서 DB를 쓰는 메서드가 트랜잭션 없이 호출되는 경우를 찾는다.
- 트랜잭션 없이 JPA save/delete/update를 호출하면 반영되지 않을 수 있다.

#### [C] 외부 API 호출을 트랜잭션 안에 포함
- Firebase, HTTP 외부 API, SQS 등 네트워크 호출이 `@Transactional` 메서드 안에 있는 경우를 찾는다.
- **왜 위험한가**: 외부 API 응답 대기 시간 동안 DB 커넥션을 점유한다. 커넥션 풀 고갈 위험.
- **올바른 해결**: afterCommit 콜백으로 이동하거나 트랜잭션 범위 밖으로 분리

#### [D] REQUIRES_NEW 남용
- 활성 트랜잭션 안에서 REQUIRES_NEW를 호출하면 외부 트랜잭션이 suspend되고 새 커넥션을 획득한다.
- 루프 안에서 REQUIRES_NEW를 반복 호출하는 경우를 찾는다. 커넥션 풀 고갈 위험.

#### [E] 트랜잭션 전파 경계 불일치
- `@Transactional(readOnly = true)` 메서드 안에서 write 메서드를 호출하는 경우
- 트랜잭션이 없는 메서드에서 JPA 더티체킹(setter 호출)에 의존하는 경우

### 4. 결과 출력 형식

분석 결과를 아래 형식으로 출력한다:

```
## 트랜잭션 패턴 리뷰

### 분석 대상 파일
- 변경 파일: N개
- 연관 파일: N개

### 발견된 문제
#### [위험도: 높/중/낮] 패턴명
- 파일: 경로:라인번호
- 문제: 구체적 설명
- 해결: 권장 방법

### 이상 없음
- 검토한 패턴 중 문제 없는 항목 목록
```

문제가 없으면 "트랜잭션 패턴 상 이상 없음" 으로 간단히 출력한다.

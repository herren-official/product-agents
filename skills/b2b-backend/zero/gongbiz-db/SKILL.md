---
name: b2b-backend-gongbiz-db
description: MariaDB에 접속하여 자연어로 데이터를 조회합니다. dev/prod 환경을 지원합니다.
argument-hint: <dev|prod> <자연어 쿼리>
context: fork
agent: general-purpose
---

# Gongbiz DB Query Skill

MariaDB CLI를 사용하여 데이터를 조회하는 범용 skill입니다.

## 입력

```text
$ARGUMENTS
```

## DB 접속 정보

### DEV 환경
```text
Host:     (set in ~/.claude/skills/gongbiz-db/dev.cnf — do not commit)
Port:     3306
Database: nailshop
User:     (set in dev.cnf)
Password: (set in dev.cnf)
```

### PROD 환경
```text
Host:     (set in ~/.claude/skills/gongbiz-db/prod.cnf — do not commit)
Port:     3306
Database: nailshop
User:     (개인별 계정 — prod.cnf에 설정)
Password: (개인별 비밀번호 — prod.cnf에 설정)
```
> 접속 정보는 모두 `~/.claude/skills/gongbiz-db/{dev,prod,prod-primary-rw}.cnf` 파일로 관리합니다 (`.gitignore`로 차단).
> PROD는 개인별 읽기전용 계정을 사용합니다. 본인 계정은 노션 "RDS 계정 목록"에서 확인 후 `prod.cnf`에 설정하세요.
> CLI 사용 예: `mariadb --defaults-file=~/.claude/skills/gongbiz-db/dev.cnf -e "..."`

## 실행 흐름

### 1단계: 입력 파싱

`$ARGUMENTS`에서 환경과 쿼리를 분리합니다:
- 첫 번째 단어: 환경 (`dev` 또는 `prod`)
- 나머지: 자연어 쿼리

환경이 지정되지 않으면 사용자에게 질문합니다.

### 2단계: 스키마 참조

주요 테이블 구조:

#### employee (직원/사용자)
| 컬럼 | 설명 |
|-----|------|
| empno | PK, 직원 번호 |
| id | 로그인 ID (예: herrenail) |
| name | 직원 이름 |
| recommendId | 추천인 ID |
| regdate | 등록일 |

#### shop (샵)
| 컬럼 | 설명 |
|-----|------|
| shopno | PK, 샵 번호 |
| name | 샵 이름 |
| contact | 연락처 |
| addr | 기본 주소 |
| addrdetail | 상세 주소 |
| duedate | 이용권 만료일 (VARCHAR, YYYYMMDD) |
| delaydue | 연장일수 |
| payment_type | 결제 유형 |

#### emplshop (직원-샵 연결)
| 컬럼 | 설명 |
|-----|------|
| empno | FK, employee.empno |
| shopno | FK, shop.shopno |
| kind | 역할 ('점주', '직원' 등) |
| state | 상태 ('등록', '삭제' 등) |

### 3단계: SQL 생성

자연어 요청을 분석하여 적절한 SELECT 쿼리를 생성합니다.

**중요**:
- **PROD**: SELECT 쿼리만 실행합니다 (READ ONLY). INSERT, UPDATE, DELETE, DROP 등은 절대 실행하지 않습니다.
- **DEV**: SELECT, INSERT, UPDATE, DELETE를 실행할 수 있습니다. 단, 사용자 승인을 받은 후 실행합니다. DROP은 금지합니다.
- 결과가 많을 수 있으므로 LIMIT 100을 기본 적용합니다

**쿼리 예시**:

```sql
-- employee id로 empno 조회
SELECT empno, id, name FROM employee WHERE id = 'herrenail';

-- employee의 연결된 샵 목록 (가용: state='등록')
SELECT e.empno, e.id, e.name, es.kind, s.shopno, s.name as shop_name, s.duedate
FROM employee e
JOIN emplshop es ON e.empno = es.empno AND es.state = '등록'
JOIN shop s ON es.shopno = s.shopno
WHERE e.id = 'herrenail';

-- 만료되지 않은 가용 샵 (duedate가 현재 이후)
SELECT e.empno, e.id, s.shopno, s.name as shop_name, s.duedate
FROM employee e
JOIN emplshop es ON e.empno = es.empno AND es.state = '등록'
JOIN shop s ON es.shopno = s.shopno
WHERE e.id = 'herrenail'
  AND (s.duedate >= DATE_FORMAT(NOW(), '%Y%m%d') OR s.duedate IS NULL);
```

### 4단계: MariaDB CLI 실행

생성한 SQL을 mariadb CLI로 실행합니다.

**중요**: config 파일 방식 사용 (비밀번호 특수문자 이스케이프 문제 방지)

**Config 파일 위치**: `~/.claude/skills/gongbiz-db/`
- `dev.cnf` - DEV 환경
- `prod.cnf` - PROD 환경

**DEV 환경 명령어**:
```bash
mariadb --defaults-file=~/.claude/skills/gongbiz-db/dev.cnf -e "YOUR_SQL_HERE"
```

**PROD 환경 명령어**:
```bash
mariadb --defaults-file=~/.claude/skills/gongbiz-db/prod.cnf -e "YOUR_SQL_HERE"
```

### 5단계: 결과 반환

쿼리 결과를 사용자에게 보기 좋게 정리하여 반환합니다.

---

## 사용 예시

```text
/gongbiz-db dev employee id=herrenail의 가용 샵 목록
/gongbiz-db prod shopno가 S000000001인 샵 정보
/gongbiz-db dev 최근 7일 내 가입한 직원 목록
/gongbiz-db prod 만료일이 지난 샵 수
```

## 주의사항

- **PROD**: READ ONLY — SELECT 쿼리만 실행합니다
- **DEV**: SELECT + INSERT/UPDATE/DELETE 가능 — 사용자 승인 후 실행
- **LIMIT**: 기본적으로 LIMIT 100을 적용합니다
- **PROD 주의**: prod 환경은 실제 운영 데이터이므로 신중하게 사용합니다
- **DEV DROP 금지**: DEV에서도 DROP TABLE/DATABASE는 실행하지 않습니다

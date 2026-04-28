---
name: b2b-backend-gongbiz-db
description: MariaDB(공비즈 nailshop)에 접속해 자연어로 데이터를 조회한다. dev/prod 환경 지원, READ ONLY(SELECT 전용) + 기본 LIMIT 100. "/gongbiz-db dev|prod {자연어}" 호출 시 사용.
argument-hint: <dev|prod> <자연어 쿼리>
context: fork
agent: general-purpose
---

# Gongbiz DB Query Skill

MariaDB CLI를 사용하여 공비즈 nailshop 데이터를 조회하는 범용 스킬이다.

## 트리거

- `/gongbiz-db dev {질문}` / `/gongbiz-db prod {질문}`
- "dev DB 조회", "prod DB 확인", "gongbiz db", "샵 정보 조회" 등

## 입력

```
$ARGUMENTS
```

## DB 접속 정보

### DEV 환경
```
Host: dev-rds-gongbiz-crm.ctu50t96dzgd.ap-northeast-2.rds.amazonaws.com
Port: 3306
Database: nailshop
```

### PROD 환경
```
Host: prod-rds-gongbiz-replica.ctu50t96dzgd.ap-northeast-2.rds.amazonaws.com
Port: 3306
Database: nailshop
```

> 자격증명은 `~/.claude/skills/gongbiz-db/{dev|prod}.cnf` 에 보관. SKILL.md에는 노출하지 않는다.

## 워크플로우

### Step 1: 입력 파싱

`$ARGUMENTS`에서 환경과 쿼리를 분리한다:
- 첫 번째 단어: 환경 (`dev` 또는 `prod`)
- 나머지: 자연어 쿼리

환경이 지정되지 않으면 사용자에게 질문한다.

### Step 2: 스키마 참조

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

### Step 3: SQL 생성

자연어 요청을 분석하여 적절한 SELECT 쿼리를 생성한다.

**중요 규칙**:
- SELECT 쿼리만 생성 (READ ONLY)
- INSERT, UPDATE, DELETE, DROP 등은 절대 실행하지 않음
- 결과가 많을 수 있으므로 기본 LIMIT 100 적용

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

### Step 4: MariaDB CLI 실행

생성한 SQL을 mariadb CLI로 실행한다. config 파일 방식을 사용한다 (비밀번호 특수문자 이스케이프 문제 방지).

**Config 파일 위치**: `~/.claude/skills/gongbiz-db/`
- `dev.cnf` — DEV 환경
- `prod.cnf` — PROD 환경

**DEV 환경**:
```bash
mariadb --defaults-file=~/.claude/skills/gongbiz-db/dev.cnf -e "YOUR_SQL_HERE"
```

**PROD 환경**:
```bash
mariadb --defaults-file=~/.claude/skills/gongbiz-db/prod.cnf -e "YOUR_SQL_HERE"
```

### Step 5: 결과 반환

쿼리 결과를 사용자에게 보기 좋게 정리하여 반환한다.

## 사용 예시

```
/gongbiz-db dev employee id=herrenail의 가용 샵 목록
/gongbiz-db prod shopno가 S000000001인 샵 정보
/gongbiz-db dev 최근 7일 내 가입한 직원 목록
/gongbiz-db prod 만료일이 지난 샵 수
```

## 주의사항

- **READ ONLY**: SELECT 쿼리만 실행
- **LIMIT**: 기본적으로 LIMIT 100 적용
- **PROD 주의**: prod 환경은 실제 운영 데이터이므로 신중히 사용
- **자격증명 보호**: SKILL.md 에 비밀번호를 직접 기록하지 않는다 (`{env}.cnf` 사용)
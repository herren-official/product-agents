---
name: b2b-backend-db
description: MCP mysql 도구로 개발 DB(nailshop)를 조회한다. "db", "DB 조회", "테이블 확인" 요청 시 트리거. SELECT 쿼리만 허용.
---

# db

MCP mysql 도구를 사용해서 개발 DB(nailshop)를 조회한다. 커맨드 실행 시 `.mcp.json`을 읽어서 접속 정보를 확인하고, `mysql_connect`로 즉시 연결.

## 연결
- `.env.local` 등 환경 파일은 읽지 마라.
- 연결 실패 시 사용자에게 에러 내용을 알려줘라.

## 사용법
- 자연어 질문이면 적절한 SQL을 작성해서 실행해줘. (예: "오늘 예약 건수", "직원 영업일 설정 확인")
- SQL이 직접 입력되면 그대로 실행해줘.

## 규칙
- SELECT만 허용. INSERT, UPDATE, DELETE, DROP, ALTER 등 데이터 변경 쿼리는 절대 실행하지 마.
- 결과가 많을 수 있으니 LIMIT 50을 기본으로 붙여줘 (사용자가 별도 지정하지 않은 경우).

## 요청 내용
$ARGUMENTS

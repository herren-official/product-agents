# maru — b2b-backend 작업자 스킬 모음

작업자 그룹: maru
프로젝트: `gongbiz-crm-b2b-backend`
호출명 prefix: `b2b-backend-*` 

## 스킬 목록

| 공정 | 스킬 호출명 | 파일 | 용도 |
|------|-----------|------|------|
| 04 Build | `/b2b-backend-gongbiz-db` | [gongbiz-db/SKILL.md](./gongbiz-db/SKILL.md) | MariaDB(nailshop) 자연어 조회 (dev/prod) |
| 07 Ship | `/b2b-backend-create-pr` | [create-pr/SKILL.md](./create-pr/SKILL.md) | GitHub PR 생성 (CRM 템플릿 + GBIZ 자동 추출) |
| 07 Ship | `/b2b-backend-commit` | [commit/SKILL.md](./commit/SKILL.md) | 변경 분석 → 한국어 커밋 메시지 1줄 추천 |


## 참고

- 호출 prefix `b2b-backend-` 는 `setup.sh` 가 `~/.claude/skills/b2b-backend-{skill}/` 평탄 링크로 풀어줌
- `PR/` 디렉토리는 사전 생성된 임시본 — `create-pr/` 와 중복이므로 정리 검토 필요
- woody/bugi 와 동일 공정에 속하는 스킬은 가급적 그쪽을 우선 사용하고, maru 는 개인 워크플로 차이가 있는 경우만 보유
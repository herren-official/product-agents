# skills/b2b-backend/zero

`gongbiz-crm-b2b-backend` 작업 시 제로(`zero@herren.co.kr`)가 사용하는 개인화 스킬 모음.

## 호출명

| 스킬 | 호출 | 용도 |
|------|------|------|
| `b2b-backend-codebase` | `/b2b-backend-codebase` | gongbiz-crm-b2b-backend 진입 + 컨벤션 로드 |
| `b2b-backend-comms-history` | `/b2b-backend-comms-history <키워드>` | 슬랙/노션 커뮤 이력 정리 |
| `b2b-backend-create-ticket` | `/b2b-backend-create-ticket <티켓명 SP ...>` | Notion 백로그 티켓 일괄 생성 |
| `b2b-backend-ec2` | `/b2b-backend-ec2 <서버> [옵션]` | EC2 SSH 로그 확인 |
| `b2b-backend-gongbiz-db` | `/b2b-backend-gongbiz-db <dev\|prod> <자연어>` | MariaDB 자연어 조회 |
| `b2b-backend-notion` | `/b2b-backend-notion <검색어>` | 노션 워크스페이스 탐색 |
| `b2b-backend-pc` | `/b2b-backend-pc <프로젝트명>` | 프로젝트 컨텍스트 로드 |
| `b2b-backend-pr-chain-rebase` | `/b2b-backend-pr-chain-rebase [PR번호]` | PR 체인 리베이스 |
| `b2b-backend-project` | `/b2b-backend-project [update]` | 진행중 프로젝트 STATUS.md 관리 |
| `b2b-backend-refactor-code-style` | `/b2b-backend-refactor-code-style <파일>` | code-style-guide.md 기반 리팩토링 |
| `b2b-backend-wrap` | `/b2b-backend-wrap` | 세션 마무리 (학습 추출, CLAUDE.md 업데이트 제안) |

## 환경 가정

스킬들은 아래 로컬 디렉토리 구조를 전제로 작성됨. 다른 사람이 사용하려면 본인 환경에 맞춰 경로를 조정해야 함.

| 경로 | 용도 |
|------|------|
| `~/herren-repo/gongbiz-crm-b2b-backend` | 백엔드 코드베이스 |
| `~/herren-repo/CLAUDE.md` | 개인 작업 규칙 |
| `~/herren-repo/code-style-guide.md` | 코드 스타일 체크리스트 |
| `~/herren-repo/projects/<프로젝트>/CONTEXT.md` | 프로젝트별 컨텍스트 |
| `~/claude-resources/notions/` | 노션 미러 + 컨벤션 문서 |
| `~/.claude/skills/gongbiz-db/*.cnf` | DB 접속 자격증명 (별도 배치, 커밋 금지) |

## 별도 배치 필요 자료

- **DB 자격증명**: `gongbiz-db` 스킬 사용 시 `~/.claude/skills/gongbiz-db/{dev,prod,prod-primary-rw}.cnf` 파일 필요. 본 레포는 `.gitignore`로 차단되어 있으니 사내 안전 채널로 별도 수령 필요.
- **노션 컨벤션**: `~/claude-resources/notions/gongbiz/{kotlin-convention,rebase-chaining-guide,squash-merge-proposal}.md`. 노션 원본 동기화 또는 별도 공유.

## 우디 하네스와의 관계

본 폴더는 우디의 AI-DLC 1차/2차 하네스(`skills/b2b-backend/woody/`, `skills/b2b-backend/<flat>/`)와 **상호 보완**:

- 우디 하네스: 스펙·설계·테스트·리뷰 등 AI-DLC 워크플로우 자동화
- zero: DB 조회·코드 진입·PR 체이닝·노션·로그 등 **백엔드 작업 보조 도구**

이름 중복: `b2b-backend-wrap`은 우디 버전과 zero 버전이 함께 등록되어 있음. 글로벌 평탄링크는 `setup.sh` 미수정 상태라 충돌 미발생. setup.sh 3단 인식 패치 시점에 일괄 정리 예정.

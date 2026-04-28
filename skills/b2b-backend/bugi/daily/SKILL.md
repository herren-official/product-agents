---
name: b2b-backend-daily
description: 하루 작업(git 커밋·PR·코드리뷰·세션)을 종합해 옵시디언에 데일리 워크 로그를 생성한다. "daily", "데일리 로그 만들어줘", "스탠드업 정리" 요청 시 트리거.
---

# daily

하루 작업을 종합해서 옵시디언에 데일리 워크 로그를 생성해준다.
사용자가 인자를 넘기면(`$ARGUMENTS`) 메모 섹션에 추가해준다.

## 날짜 계산

이 스킬은 **23시에 실행**되어 **다음 날 아침 스탠드업용 문서**를 미리 생성한다.

```bash
DOW=$(date +%u)  # 1=월, ..., 5=금
TODAY=$(date +%Y-%m-%d)           # 어제한일 수집 기준 (실행 당일 작업)

if [ "$DOW" = "5" ]; then
  # 금요일 → 월요일 파일 생성, 어제한일은 금요일(오늘)
  FILE_DATE=$(date -v+3d +%Y-%m-%d)
else
  # 월~목 → 다음 날 파일 생성, 어제한일은 오늘
  FILE_DATE=$(date -v+1d +%Y-%m-%d)
fi
```

| 변수 | 의미 | 예시 (목 23시) | 예시 (금 23시) |
|------|------|---------------|---------------|
| `TODAY` | 어제한일 수집 기준 | 목요일 | 금요일 |
| `FILE_DATE` | 출력 파일 날짜 + 제목 | 금요일 | 월요일 |

아래 모든 섹션에서 어제한일/코드리뷰/세션 수집은 `TODAY` 기준, 출력 파일과 제목은 `FILE_DATE` 기준으로 사용한다.

## 수집 소스

### 1. Git 커밋 (TODAY)
```bash
git log --after="${TODAY}T00:00:00" --before="${TODAY}T23:59:59" --oneline --all
```
- GBIZ 번호별로 그룹핑
- 커밋 메시지에서 작업 내용 요약

### 2. PR 활동 (어제)

**내 PR 생성/머지 (어제한일용):**
```bash
gh pr list --author @me --state all --json number,title,state,createdAt,updatedAt --jq '.[] | select((.createdAt | startswith("{TODAY}")) or (.updatedAt | startswith("{TODAY}")))'
```

**코드리뷰 (다른 사람 PR에 내가 실제로 어제 리뷰한 것만):**
`search/issues?q=commenter:@me`는 PR의 `updated` 시점 기준이라 오래된 PR까지 딸려오므로 사용하지 말 것. 대신 아래 2개 엔드포인트로 **내가 어제 실제 제출한 리뷰/코멘트**만 추출:

```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)

# (1) 인라인 리뷰 코멘트 — 어제 내가 단 코멘트가 있는 PR 번호 unique
gh api "repos/${REPO}/pulls/comments?sort=updated&direction=desc&per_page=100" \
  --jq '[.[] | select(.user.login == "<github-username>" and (.created_at | startswith("{TODAY}"))) | .pull_request_url | split("/") | last] | unique | .[]'

# (2) 각 PR에서 어제 제출한 리뷰 개수 확인 (review submission)
for pr in $PR_LIST; do
  count=$(gh api "repos/${REPO}/pulls/${pr}/reviews" \
    --jq "[.[] | select(.user.login == \"<github-username>\" and (.submitted_at | startswith(\"{TODAY}\")))] | length")
  [ "$count" -gt 0 ] && echo "#${pr}: ${count}건"
done
```

**주의:**
- **내가 author인 PR은 코드리뷰에서 제외** (PR author와 commenter가 같으면 스킵)
- 리뷰 개수가 0인 PR은 제외
- 인라인 코멘트 없이 issue comment만 있는 경우 `repos/${REPO}/issues/comments` 엔드포인트도 별도 확인

### 3. Claude Code 세션 요약 (TODAY) ⭐ 핵심
실행 당일(TODAY) 세션 JSONL 파일을 읽고 **AI 요약**한다.

1. `<세션 디렉토리>/*.json`에서 TODAY 날짜의 세션 ID 추출
   ```bash
   python3 -c "
   import json, glob, os, datetime
   target = datetime.date.today().isoformat()  # 실행 당일 = TODAY
   for f in glob.glob(os.path.expanduser('<세션 디렉토리>/*.json')):
       data = json.load(open(f))
       started = datetime.datetime.fromtimestamp(data['startedAt']/1000).date().isoformat()
       if started == target:
           print(data['sessionId'])
   "
   ```
2. 각 세션의 JSONL 파일 경로: `<프로젝트 세션 디렉토리>/{sessionId}.jsonl`
3. JSONL을 Read 도구로 읽고, 사용자 메시지(role=human/user)에서 **커밋에 안 잡히는 작업**을 추출:
   - 노션 연동/코멘트 작업
   - 문서 작성/정책 논의
   - DB 조사/쿼리 작업
   - 코드 리뷰/답글
   - 설계 결정사항
4. 짧은 응답("ㅇㅇ", "응", "확인") 무시, 실질적 작업 내용만 요약

### 4. 옵시디언 태스크 문서 (오늘할일 + 막히는점)
```bash
# 현재 작업중인 프로젝트의 태스크 문서들
find <옵시디언 vault>/ -name "*.md" -path "*/tasks/*" -type f
```
- **오늘할일**: 상태가 "대기" 또는 "진행중"인 태스크에서 미완료 체크리스트(`- [ ]`) 추출
- **막히는점**: 태스크 문서에서 `미확정`, `확정 필요`, `TBD`, `미결`, `TODO` 키워드가 포함된 항목 추출

## 출력 파일
- 경로: `<옵시디언 vault>/daily/{FILE_DATE}.md` (**다음 날** 날짜 기준)
- 예: 목 23시 실행 → `금요일.md`, 금 23시 실행 → `월요일.md`
- `daily/` 폴더 없으면 자동 생성

## 파일 형식

```markdown
# {FILE_DATE} ({FILE_DATE의 요일}) 데일리 스탠드업

## 어제한일
- **GBIZ-26097**: ExpirationPeriod null 방어 리팩토링 → PR #5163 머지
- 노션 백로그 8건 등록 (GBIZ-26101~26108), 옵시디언 태스크 문서 반영
- OPTION_PERIOD 타입 도입 결정 — 정책/api-spec/노션 반영
- 매출에 사용된 삭제 시술 현황 DB 조사

## 코드리뷰
- #5200 알림톡 AI 필터 — AOP vs 인터셉터 vs 서비스 호출 방식 검토
- B2C 콕예약 PR 6건 (#5158, #5173, #5176, #5178, #5181, #5098)

## 오늘할일
- GBIZ-26101: DB 작업 — customer_filter_condition UPDATE 3건
- GBIZ-26103: 고객차트 필터 담당자 — PeriodRequirement 도입, Validator 확장
- PR 리뷰 코멘트 대응

## 막히는점
- GBIZ-26104 받은시술: optionValues children 구조 미결 (2단계 표현 방식, 매출 이력 기준 시술 조회)

---
> 생성: /b2b-backend-daily 커맨드 ({시각})
```

## 작성 규칙
- **어제한일**: git 커밋 + PR 생성/머지 + 세션 요약을 합쳐서 **중복 제거** 후 작성. 커밋으로 이미 잡힌 작업은 세션에서 반복하지 않음. **리뷰 코멘트 활동은 제외** (코드리뷰 섹션에서 별도 표시)
- **코드리뷰**: PR 코멘트 활동 + 세션에서 추출된 코드 리뷰 작업. 내가 author인 PR은 제외하고 **다른 사람 PR에 리뷰한 것만** 표시
- **오늘할일**: 태스크 문서 상태/체크리스트 기반. 구체적 작업 단위로 작성
- **막히는점**: 미확정/미결 사항만. 해결된 건 제외
- 각 항목은 슬랙에 바로 붙여넣기 가능한 간결한 한 줄로 작성
- GBIZ 번호가 있으면 앞에 붙이기

## 기존 파일 처리
- 같은 날짜 파일이 이미 있으면 내용을 **갱신** (덮어쓰기 전에 확인)
- 기존 메모가 있으면 보존

## 완료 후
- 터미널에 슬랙에 붙여넣기 가능한 형태로 요약 출력

---
name: instaget-backend-pr-creator
description: 현재 브랜치의 변경사항을 분석하여 프로젝트 PR 템플릿에 맞게 GitHub PR을 생성합니다.
---

# PR Creator

현재 브랜치의 커밋/변경사항을 분석하여 프로젝트 표준 PR 템플릿으로 GitHub PR을 생성합니다.

## When to Use This Skill

사용 시점:
- "PR 올려줘", "PR 생성해줘", "create PR", "/instaget-backend-pr-creator"
- 브랜치명이나 타겟 브랜치와 함께 사용 가능 (예: "develop으로 PR 올려줘")
- 기본 타겟 브랜치: `develop`

## PR Creation Workflow

### Step 1: 현재 브랜치 상태 확인

```bash
# 현재 브랜치명 확인
git branch --show-current

# 리모트 트래킹 상태 확인
git status

# 커밋되지 않은 변경사항 확인
git diff --stat
git diff --cached --stat

# 푸시되지 않은 커밋 확인
git log origin/$(git branch --show-current)..HEAD --oneline 2>/dev/null || git log --oneline -20
```

**주의**: 커밋되지 않은 변경사항이 있으면 사용자에게 알림.

### Step 2: 변경사항 분석

```bash
# 베이스 브랜치(develop)와의 차이 확인
git diff develop...HEAD --stat
git diff develop...HEAD

# 커밋 히스토리 확인
git log develop..HEAD --oneline

# 변경된 파일 목록
git diff develop...HEAD --name-only
```

분석 항목:
- 영향받는 모듈 (파일 경로에서 추출)
- 작업 구분 (커밋 메시지/변경 내용에서 판단)
- 주요 변경사항 요약

### Step 3: PR 제목 생성

브랜치명에서 Jira 티켓 번호를 추출하여 PR 제목을 생성한다.

규칙:
- 브랜치명 패턴: `{TICKET}-description` (예: `IQLX-6873-add-point-product`)
- PR 제목 형식: `[{TICKET}] {한글 설명}` (예: `[IQLX-6873] 적립금 충전 상품 구현`)
- 티켓 번호가 없으면 변경 내용 기반으로 제목 생성

**중요**: PR 제목은 사용자에게 확인받는다.

### Step 4: PR 본문 생성

아래 템플릿에 맞춰 PR 본문을 생성한다.

```markdown
# **작업 구분**
- [ ] Bug Fix
- [ ] Hot Fix
- [ ] New Feature
- [ ] Breaking Change
- [ ] Documentation Update

# **작업 설명**
**상세내용(코드 변경 사항)**

{변경사항을 한글로 상세 설명}

## **Summary**

### 주요 변경사항

{모듈/기능별로 그룹핑하여 설명}

---

# **관련 작업 모듈**
### 공통
- [ ] common
- [ ] infrastructure
### 서비스
- [ ] b2c_api
- [ ] task_scheduler
- [ ] task_client
- [ ] daily_task_crawler
- [ ] instagram_crawler_api
- [ ] instarter_order_automation
- [ ] notification
- [ ] back_office_api
- [ ] monitoring

# **확인(테스트) 방법**
```bash
{관련 테스트 실행 명령어}
```

# **이슈 사항**
{알려진 이슈 또는 "없음"}

# **기타**
{추가 참고사항 또는 "없음"}
```

작성 규칙:
1. **작업 구분**: 변경 내용에 맞는 항목에 `[x]` 체크
2. **작업 설명**: 전체 변경의 목적과 상세 내용을 한글로 작성
3. **Summary**: 모듈/기능별로 번호 매겨 그룹핑
4. **관련 작업 모듈**: 변경된 파일이 속한 모듈에 `[x]` 체크
5. **확인 방법**: 관련 모듈의 테스트 명령어 제공
6. **이슈 사항**: DB 마이그레이션, 환경 설정 등 배포 시 주의사항

### Step 5: 사용자 확인

PR 제목과 본문을 터미널에 미리보기로 출력한 후 사용자에게 확인:
"이 내용으로 PR을 생성할까요?"

### Step 6: PR 생성

승인 시 실행:

```bash
# 리모트에 푸시 (필요한 경우)
git push -u origin $(git branch --show-current)

# PR 생성 (Assignee를 본인으로 지정)
gh pr create \
  --repo herren-official/instaget-server \
  --base develop \
  --head $(git branch --show-current) \
  --assignee @me \
  --title "{PR 제목}" \
  --body "$(cat <<'EOF'
{PR 본문}
EOF
)"
```

생성 후 PR URL을 사용자에게 반환한다.

## Workflow Example

사용자: "PR 올려줘"

1. `git branch --show-current` -> `IQLX-7000-cash-receipt-return`
2. `git diff develop...HEAD --stat` -> 변경 파일 분석
3. `git log develop..HEAD --oneline` -> 커밋 히스토리
4. PR 제목 생성: `[IQLX-7000] 현금영수증 발행 반송 상태 추가`
5. PR 본문 생성 (템플릿 적용)
6. 미리보기 출력 -> "이 내용으로 PR을 생성할까요?"
7. 승인 시 `gh pr create` 실행
8. PR URL 반환

## Troubleshooting

**Issue**: 리모트에 브랜치가 없는 경우
- **Solution**: `git push -u origin {branch}` 자동 실행

**Issue**: develop 브랜치가 로컬에 없는 경우
- **Solution**: `git fetch origin develop` 후 `origin/develop` 기준으로 비교

**Issue**: 커밋되지 않은 변경사항이 있는 경우
- **Solution**: 사용자에게 커밋 먼저 하도록 안내

---
name: instaget-backend-commit-push
description: 현재 변경사항을 분석하여 커밋 메시지를 생성하고, 커밋 후 리모트에 푸시합니다.
---

# Commit & Push

변경사항을 분석하여 컨벤션에 맞는 커밋 메시지를 생성하고, 커밋 및 푸시를 수행합니다.

## When to Use This Skill

사용 시점:
- "커밋 앤 푸시", "커밋하고 푸시해줘", "commit and push", "/instaget-backend-commit-push"
- "커밋해줘" (푸시 없이 커밋만)
- "푸시해줘" (이미 커밋된 상태에서 푸시만)

## Workflow

### Step 1: 현재 상태 확인

아래 명령어를 **병렬로** 실행한다.

```bash
# 변경된 파일 확인
git status

# staged + unstaged 변경 내용 확인
git diff
git diff --cached

# 최근 커밋 메시지 스타일 확인
git log --oneline -5
```

**주의사항:**
- 변경사항이 없으면 커밋하지 않는다.
- `.env`, `credentials`, API 키 등 민감 파일이 포함되어 있으면 경고한다.

### Step 2: 커밋 메시지 생성

브랜치명에서 Jira 티켓 번호를 추출하고, 변경 내용을 분석하여 커밋 메시지를 생성한다.

#### 커밋 메시지 컨벤션

```
{type}({TICKET}): {한글 설명}
```

- **type**: `feat`, `fix`, `refactor`, `test`, `docs`, `chore` 중 선택
  - `feat`: 새 기능 추가
  - `fix`: 버그 수정
  - `refactor`: 코드 리팩토링 (기능 변경 없음)
  - `test`: 테스트 추가/수정
  - `docs`: 문서 변경
  - `chore`: 빌드, 설정 등 기타
- **TICKET**: 브랜치명에서 추출 (예: `IQLX-6934`)
- **설명**: 변경 내용을 한글로 간결하게 작성

#### 예시

```
feat(IQLX-6934): QnA 일괄 답변 내부 API 추가
fix(IQLX-7001): 주문 상태 변경 시 NPE 수정
refactor(IQLX-6918): 리필 서비스 패키지 구조 변경
```

### Step 3: 커밋 실행

```bash
# 변경 파일 스테이징 (파일명 명시)
git add {file1} {file2} ...

# 커밋
git commit -m "$(cat <<'EOF'
{커밋 메시지}

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

**규칙:**
- `git add .` 또는 `git add -A` 대신 파일을 명시적으로 추가한다.
- 민감 파일은 절대 스테이징하지 않는다.

### Step 4: 푸시

```bash
# 리모트 트래킹 확인 후 푸시
git push -u origin $(git branch --show-current)
```

### Step 5: 결과 확인

```bash
git status
```

푸시 완료 후 결과를 사용자에게 알린다.

## Troubleshooting

**Issue**: pre-commit hook 실패
- **Solution**: 실패 원인을 확인하고 수정 후 새 커밋을 생성한다. `--amend` 사용 금지.

**Issue**: 리모트 브랜치가 없는 경우
- **Solution**: `git push -u origin {branch}`로 자동 생성

**Issue**: 리모트와 충돌
- **Solution**: 사용자에게 알리고 `git pull --rebase` 또는 merge 방법을 제안한다.

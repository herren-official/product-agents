---
name: b2c-android-my-pr
description: "내가 올린 PR의 승인/코멘트/리뷰 상태 확인. Use when: 내 PR 확인, PR 상태, 리뷰 상태 확인, PR 현황"
argument-hint: "[repo] (예: b2c, crm, all)"
allowed-tools: ["bash"]
---

# 내 PR 상태 확인

내(dana-herren)가 올린 열린 PR들의 리뷰 승인, 코멘트, 변경 요청 상태를 한눈에 확인합니다.

## 1. 인자 처리

| 인자 | 레포 |
|------|------|
| 없음 / `b2c` | `herren-official/gongbiz-b2c-android` |
| `crm` | `herren-official/gongbiz-crm-android` |
| `all` | 두 레포 모두 |

## 2. PR 목록 조회
```bash
gh pr list --repo {repo} --author dana-herren --state open --json number,title,createdAt,headRefName,baseRefName,reviewDecision,additions,deletions,labels,assignees
```

## 3. 각 PR별 상세 상태 수집
- 리뷰 상태 (승인/변경요청/코멘트)
- 일반 코멘트 / 코드 리뷰 코멘트 개수

## 4. 결과 출력
```
| # | 제목 | 브랜치 | 리뷰 상태 | 리뷰어 | 코멘트 | 생성일 |
```

### 주의가 필요한 PR 요약
- 변경 요청 → 수정 후 재요청 필요
- 리뷰 없음 → 리뷰어 지정/리마인드 필요
- 승인됨 → 머지 가능

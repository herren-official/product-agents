---
name: b2b-backend-review-fix
description: 리뷰 지적사항 수정 확인 (delta 리뷰)
argument-hint: [file-path]
user-invocable: true
allowed-tools: Read, Bash, Grep, Glob
---

이전 리뷰에서 지적된 항목이 올바르게 수정되었는지 확인해라.

## 입력

$ARGUMENTS

- 인자가 파일 경로이면 해당 파일의 최근 변경만 확인한다.
- 인자가 없으면 현재 대화에서 이전에 실행된 `/review`, `/review-security`, `/review-perf` 결과에서 CRITICAL과 WARNING 항목을 추출하여, 해당 파일:라인을 대상으로 한다.
- 이전 리뷰 결과가 대화에 없으면 "이전 리뷰 결과를 찾을 수 없습니다. `/review`를 먼저 실행하거나 대상 파일을 직접 지정해 주세요."를 출력한다.

## 절차

### Step 1: 이전 지적사항 수집
- 현재 대화에서 이전 리뷰의 CRITICAL/WARNING 항목(파일:라인, 문제, 개선안)을 추출한다.
- 추출된 항목이 없으면 `git diff HEAD~1` 또는 `git diff --staged`로 최근 변경을 대상으로 한다.

### Step 2: 수정 여부 확인
각 지적사항에 대해:
- 해당 파일:라인의 현재 코드를 읽는다.
- 이전 지적의 개선안 방향대로 수정되었는지 확인한다.
- Entity-Schema 정합성 지적사항의 경우, Entity 파일과 대응하는 마이그레이션 파일을 함께 확인한다.
- 수정 과정에서 새로운 문제가 도입되지 않았는지 확인한다.

### Step 3: 판정
각 항목에 대해:
- **수정 완료**: 개선안대로 올바르게 수정됨
- **부분 수정**: 일부만 반영됨, 추가 수정 필요
- **미수정**: 변경 없음
- **새 문제 도입**: 수정 과정에서 새로운 CRITICAL/WARNING 발생

## 출력 형식

```markdown
## 수정 확인 리뷰

### 확인 대상
- 이전 리뷰: [/review | /review-security | /review-perf]
- CRITICAL: [N]개 / WARNING: [N]개

### 수정 확인 결과
| # | 원본 심각도 | 파일:라인 | 원본 문제 | 수정 상태 | 비고 |
|---|-----------|----------|----------|----------|------|
| 1 | CRITICAL | OrderService.kt:45 | 트랜잭션 내 HTTP 호출 | 수정 완료 | 이벤트 기반으로 분리됨 |
| 2 | WARNING | OrderRepo.kt:12 | N+1 쿼리 | 부분 수정 | fetch join 적용했으나 카운트 쿼리 분리 안 됨 |
| 3 | WARNING | UserController.kt:30 | @Valid 누락 | 미수정 | |

### 새로 발견된 문제 (수정 과정에서 도입)
| # | 심각도 | 파일:라인 | 문제 | 개선안 |
|---|--------|----------|------|--------|
| 1 | WARNING | OrderService.kt:50 | 이벤트 리스너에 @TransactionalEventListener 누락 | AFTER_COMMIT 적용 필요 |

### 총평
- 수정 완료: [N]개 / 부분 수정: [N]개 / 미수정: [N]개 / 새 문제: [N]개
- 전체 판정: [수정 확인 완료 / 추가 수정 필요]

### 다음 단계
- 추가 수정 후 다시 `/review-fix`를 실행하세요.
- 종합 리뷰가 필요하면 `/review`를 실행하세요.
```

## 제약

- 프로덕션 코드를 직접 수정하지 않는다. 수정 필요 사항을 출력으로 제시한다.
- 이전 리뷰에서 지적되지 않은 새로운 문제는 "새로 발견된 문제" 섹션에서만 다룬다. 전체 재리뷰를 수행하지 않는다.
- INFO 항목은 재확인 대상에서 제외한다. CRITICAL과 WARNING만 확인한다.

# PR Reviewer Skill (fineadple-server)

GitHub PR을 로컬에서 분석하여 코드 리뷰를 수행하는 Claude Code 스킬입니다.

## 주요 기능

- PR diff 자동 분석 (모듈/파일 분류)
- 3단계 심각도별 체크리스트 리뷰 (Critical / Major / Suggestion)
- 리뷰 결과 터미널 출력 + GitHub PR 코멘트 등록

## 사용 방법

```
리뷰해줘 {PR번호}
PR 리뷰해줘 {PR번호}
review PR {PR번호}
```

### 예시

```
리뷰해줘 123
```

## 워크플로우

```
PR 번호 입력
  -> gh CLI로 PR 정보/diff 수집
  -> analyze_pr.py로 모듈 자동 감지
  -> 체크리스트 기반 리뷰 (Critical -> Major -> Suggestion)
  -> 터미널에 결과 출력
  -> (선택) GitHub PR 코멘트로 등록
```

## 사전 요구사항

- **GitHub CLI** (`gh`): `brew install gh` (macOS)
- **Python 3**: 분석 스크립트 실행용
- **Claude Code**: 스킬 실행 환경

## 파일 구조

```
pr-reviewer/
├── README.md                          # 이 파일
├── SKILL.md                           # 스킬 정의 및 워크플로우
├── scripts/
│   └── analyze_pr.py                  # PR 분석 스크립트
└── references/
    ├── review-checklist.md            # 통합 리뷰 체크리스트 (3단계 심각도)
    ├── review-comment-template.md     # GitHub PR 코멘트 템플릿
    └── domain-review-points.md        # 도메인별 리뷰 포인트
```

## 리뷰 체크리스트 심각도

| Level | 이름 | 설명 |
|-------|------|------|
| Critical | 반드시 수정 | DDL 안전성, NPE 위험, 트랜잭션 경계, PII 로깅, 외부 API |
| Major | 수정 권장 | 네이밍, 로깅, 아키텍처, 엣지 케이스, 테스트, Kafka |
| Suggestion | 선택적 개선 | 코드 스타일, 인터페이스 분리 |

## 대상 모듈

fineadple_common, fineadple_infrastructure, fineadple_b2c_api, fineadple_advertiser_center_api, fineadple_authentication_api, fineadple_backoffice_api, fineadple_batch, fineadple_crawler_api, fineadple_notification_api, fineadple_lambda

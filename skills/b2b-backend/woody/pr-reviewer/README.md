# PR Reviewer Skill

GitHub PR을 로컬에서 분석하여 코드 리뷰를 수행하는 Claude Code 스킬입니다.
200개 PR 리뷰 분석 결과를 기반으로 한 체크리스트로 리뷰합니다.

## 주요 기능

- PR diff 자동 분석 (모듈/도메인/파일 분류)
- 4단계 심각도별 체크리스트 리뷰 (Critical / Major / Suggestion / Domain)
- 12개 도메인별 전문 리뷰 포인트 자동 적용
- 리뷰 결과 터미널 출력 + GitHub PR 코멘트 등록

## 설치 방법

### 1. 심볼릭 링크로 등록 (권장)

프로젝트 루트에서 실행:

```bash
# .claude/skills 디렉토리가 없으면 생성
mkdir -p .claude/skills

# 심볼릭 링크 생성
ln -s ../../.docs/crm/shared/skills/pr-reviewer .claude/skills/pr-reviewer
```

### 2. 직접 복사 (대안)

```bash
mkdir -p .claude/skills
cp -r .docs/crm/shared/skills/pr-reviewer .claude/skills/pr-reviewer
```

> 직접 복사 시 공통 업데이트가 자동 반영되지 않습니다. 심볼릭 링크를 권장합니다.

### 설치 확인

Claude Code에서 `/pr-reviewer` 입력 시 스킬이 인식되면 설치 완료입니다.

## 사용 방법

```
리뷰해줘 {PR번호}
PR 리뷰해줘 {PR번호}
review PR {PR번호}
```

### 예시

```
리뷰해줘 4850
```

## 워크플로우

```
PR 번호 입력
  → gh CLI로 PR 정보/diff 수집
  → analyze_pr.py로 모듈/도메인 자동 감지
  → 체크리스트 기반 리뷰 (Critical → Major → Suggestion → Domain)
  → 터미널에 결과 출력
  → (선택) GitHub PR 코멘트로 등록
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
    ├── review-checklist.md            # 통합 리뷰 체크리스트 (4단계 심각도)
    ├── domain-review-points.md        # 12개 도메인별 리뷰 포인트
    └── review-comment-template.md     # GitHub PR 코멘트 템플릿
```

## 리뷰 체크리스트 심각도

| Level | 이름 | 설명 |
|-------|------|------|
| 🔴 Critical | 반드시 수정 | DDL 안전성, NPE 위험, 트랜잭션 경계, PII 로깅 |
| ⚠️ Major | 수정 권장 | 네이밍, 로깅, 아키텍처, 엣지 케이스, 테스트 |
| 💡 Suggestion | 선택적 개선 | 코드 스타일, 인터페이스 분리 |
| 🏢 Domain | 도메인별 | 감지된 도메인에 따라 동적 적용 |

## 지원 도메인 (12개)

예약, 결제, 정산, 매출, 샵, 고객, 시술, 직원, 알림, 네이버, 이용권/정기권, 영업일

## 제거 방법

```bash
# 심볼릭 링크로 설치한 경우
rm .claude/skills/pr-reviewer

# 직접 복사한 경우
rm -rf .claude/skills/pr-reviewer
```

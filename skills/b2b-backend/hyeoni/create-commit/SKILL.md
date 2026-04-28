---
name: b2b-backend-create-commit
description: 현재 git 변경사항을 레이어별로 분리하여 자동으로 커밋을 생성한다. 도메인/서비스/테스트/마이그레이션 단위로 분리.
---

# 자동 커밋 생성 커맨드

## 사용 방법
이 커맨드를 실행하면 현재 변경된 파일들을 분석하여 기능 단위로 잘게 나눠서 자동으로 커밋합니다.

## 커밋 컨벤션
- **타입 종류**
  - `feat`: 새로운 기능 추가
  - `fix`: 버그 수정
  - `docs`: 문서 관련
  - `style`: 스타일 변경 (포매팅 수정, 들여쓰기 추가 등)
  - `refactor`: 코드 리팩토링
  - `test`: 테스트 관련 코드
  - `build`: 빌드 관련 파일 수정
  - `ci`: CI 설정 파일 수정
  - `perf`: 성능 개선
  - `chore`: 그 외 자잘한 수정

- **커밋 메시지 형식**
  - `<타입>(<작업번호>): <간단한 설명>`
  - 첫 글자 소문자, 마침표 미사용
  - 명령문 현재 시제 사용
  - 작업번호 예: `GBIZ-20263` (노션 작업 카드 번호)

## 실행 순서

### 1단계: 현재 변경사항 확인
```bash
git status --short
git diff
```

### 2단계: 기능별 커밋 분리

#### 엔티티/도메인 수정 커밋
```bash
git add [엔티티 파일 경로]
git commit -m "feat(GBIZ-XXXXX): [엔티티명] 엔티티에 [필드/기능] 추가

- [추가된 필드/기능 1]
- [추가된 필드/기능 2]
- [변경 이유나 배경]"
```

#### 비즈니스 로직 구현 커밋
```bash
git add [서비스/핸들러 파일 경로]
git commit -m "feat(GBIZ-XXXXX): [기능명] 기능 구현

- [구현 내용 1]
- [구현 내용 2]
- [비즈니스 규칙 설명]"
```

#### 테스트 코드 커밋
```bash
git add [테스트 파일 경로]
git commit -m "test(GBIZ-XXXXX): [대상 클래스명] 테스트 코드 작성

- [테스트 케이스 1]
- [테스트 케이스 2]
- [테스트 커버리지 정보]"
```

#### 문서 수정 커밋
```bash
git add [문서 파일 경로]
git commit -m "docs(GBIZ-XXXXX): [문서명] 업데이트

- [변경 내용 1]
- [변경 내용 2]"
```

### 3단계: 커밋 확인
```bash
git log --oneline -10
git show HEAD
```

## 자동 커밋 메시지 생성

### 파일 타입별 분류 로직
- 도메인 파일 (`domain/.+\.(kt|java)$` 제외 Test): `feat` + 도메인 모델 수정
- 서비스 파일 (`(application|service)/.+\.(kt|java)$` 제외 Test): `feat` + 비즈니스 로직 구현
- 컨트롤러 (`presentation/.+Controller\.(kt|java)$`): `feat` + 비즈니스 로직 구현
- 테스트 (`Test\.(kt|java)$`): `test` + 테스트 코드 작성
- 마이그레이션 (`migration/.+\.xml$`): `feat` + 데이터베이스 마이그레이션
- 설정 파일 (`yml|yaml|properties|xml$`): `chore` + 설정
- 문서 (`\.(md|txt|adoc)$`): `docs`

### 작업 번호 자동 추출
```bash
BRANCH=$(git branch --show-current)
TASK_NUMBER=$(echo $BRANCH | grep -oE 'GBIZ-[0-9]+' | head -1)
```

브랜치명에서 추출 실패 시 사용자에게 직접 입력 요청.

## 커밋 분리 원칙

### 좋은 커밋 분리 예시
- 도메인 모델 변경과 비즈니스 로직을 분리
- 기능 구현과 테스트 코드를 분리
- 리팩토링과 기능 변경을 분리
- 설정 파일 변경을 별도로 분리

### 피해야 할 커밋
- 여러 기능을 한 커밋에 포함
- 테스트 없는 기능 구현
- 설명 없는 대량 변경
- 컴파일 오류가 있는 상태로 커밋

## 주의사항

- 커밋 전 반드시 테스트 실행
- 커밋 메시지는 팀원이 이해할 수 있도록 명확하게 작성
- 대규모 리팩토링은 별도 브랜치에서 작업
- 민감한 정보(패스워드, API 키 등)가 포함되지 않도록 주의
- **커밋 메시지에 절대 포함하지 말 것:**
  - `Generated with [Claude Code]`
  - `Co-Authored-By: Claude <noreply@anthropic.com>`
  - 위 문구들은 자동 생성 표시이므로 커밋 메시지에 포함하지 않음

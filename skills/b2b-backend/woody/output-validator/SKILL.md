---
name: b2b-backend-output-validator
description: 에이전트 산출물의 형식을 검증하고, 줄바꿈/entity 오류를 자동 수정하는 스킬. 오케스트레이터가 각 Phase 완료 후 호출한다.
---

# 산출물 형식 검증 (output-validator)

## 역할

에이전트가 생성한 markdown 산출물의 형식을 검증하고, 일반적인 오류(줄바꿈 리터럴, HTML entity, 빈 파일 등)를 자동 수정한다.

## 입력

- **파일 경로**: 검증할 산출물 파일의 절대 경로
- **(선택) 최소 줄 수**: 기본값 5
- **(선택) 최소 heading 수**: 기본값 2

## 출력

- 검증 결과 (PASS/FAIL/FIXED)
- 수정된 경우 수정 내용 요약

## 워크플로우

### Step 1: 파일 존재 확인

Read 도구로 파일 첫 10줄을 읽는다.
- 파일 미존재 → **FAIL** + "파일 없음" 보고
- 빈 파일 → **FAIL** + "빈 파일" 보고

### Step 2: 줄 수 확인

Bash `wc -l` 으로 줄 수 확인.
- 줄 수 < 최소 줄 수(기본 5) → **줄바꿈 리터럴 의심**
- Step 3으로 진행하여 자동 수정 시도

### Step 3: 줄바꿈 리터럴 검사 + 자동 수정

Bash Python 스크립트로 검사:
```python
with open(filepath) as f:
    content = f.read()

fixed = False

# \\n 리터럴 → 실제 줄바꿈
if '\\n' in content:
    content = content.replace('\\\\n', '\n').replace('\\n', '\n')
    fixed = True

# \\t 리터럴 → 실제 탭
if '\\t' in content:
    content = content.replace('\\t', '\t')
    fixed = True

# HTML entity 디코딩
for old, new in [('&gt;', '>'), ('&lt;', '<'), ('&amp;', '&'), ('&#39;', "'"), ('&quot;', '"')]:
    if old in content:
        content = content.replace(old, new)
        fixed = True

if fixed:
    with open(filepath, 'w') as f:
        f.write(content)
```

### Step 4: heading 구조 확인

Bash `grep -c '^## ' {filepath}` 로 ## heading 수 확인.
- heading < 최소 heading 수(기본 2) → **WARN** + "heading 부족" 경고

### Step 5: 첫 줄 검사

첫 줄이 `{` 또는 `[` 로 시작하면 → **WARN** + "JSON 미파싱 가능성" 경고

### Step 6: 결과 보고

| 결과 | 의미 |
|------|------|
| **PASS** | 모든 검증 통과 |
| **FIXED** | 오류 발견 → 자동 수정 완료 (줄바꿈/entity) |
| **WARN** | heading 부족 또는 JSON 의심 — 내용 확인 필요 |
| **FAIL** | 파일 없음 또는 빈 파일 — 에이전트 재실행 필요 |

보고 형식:
```
[output-validator] {파일명}: {결과}
  - 줄 수: {N}줄
  - heading: {N}개
  - 수정: {수정 내용 또는 "없음"}
```

## 사용 예시

오케스트레이터에서 각 Phase 완료 후:
```
# 산출물 검증
output-validator 실행:
  파일: {작업디렉토리}/01_luna_requirements.md
  결과 확인 후 다음 Phase 진행
```

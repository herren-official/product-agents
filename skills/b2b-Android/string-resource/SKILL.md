---
name: b2b-android-string-resource
description: 문자열 리소스 추가. "문자열 추가", "string resource", "텍스트 추가", "strings.xml" 요청 시 사용
allowed-tools: Bash, Read, Write, Edit, Grep
user-invocable: true
---

# String Resource 스킬

strings.xml에 문자열 리소스를 프로젝트 컨벤션에 맞게 추가한다.

## 실행 단계

### 1단계: 컨벤션 확인
`.docs/conventions/string-resource-convention.md` 파일 읽기

### 2단계: 기존 리소스 확인
```bash
grep -r "name=\"{keyword}" app/src/main/res/values/strings.xml
```

### 3단계: 네이밍 결정
패턴: `{feature}_{screen}_{용도}`

### 4단계: strings.xml에 추가

## 네이밍 패턴

### 기본 형식
```
{feature}_{screen}_{용도}
```

### 용도별 접미사
| 용도 | 접미사 | 예시 |
|------|--------|------|
| 제목 | `_title` | `customer_add_title` |
| 내용 | `_content` | `login_error_content` |
| 힌트 | `_hint` | `customer_name_hint` |
| 다이얼로그 | `_dialog_title` | `delete_dialog_title` |
| 토스트 | `toast_` | `toast_save` |
| 에러 | `error_` | `error_network` |

## 예시

```xml
<!-- 화면 제목 -->
<string name="customer_add_title">고객 추가</string>
<string name="sale_register_title">매출 등록</string>

<!-- 힌트 -->
<string name="customer_name_hint">고객 이름을 입력해 주세요.</string>

<!-- 다이얼로그 -->
<string name="customer_delete_dialog_title">고객 정보 삭제</string>
<string name="customer_delete_dialog_content">정말 삭제하시겠습니까?</string>

<!-- 토스트 -->
<string name="toast_save">저장되었습니다.</string>
<string name="toast_delete">삭제되었습니다.</string>

<!-- 에러 -->
<string name="error_network">네트워크 오류가 발생했습니다.</string>
```

## 핵심 규칙

### ✅ 필수
- snake_case 사용
- 계층적 네이밍 (`기능_화면_용도`)
- 기존 공통 문자열 재사용 (`ok`, `cancel`, `save` 등)

### ⛔ 금지
- 하드코딩된 문자열
- 중복 문자열 추가
- camelCase, PascalCase

## 공통 문자열 (재사용)

```xml
<string name="ok">확인</string>
<string name="cancel">취소</string>
<string name="save">저장</string>
<string name="delete">삭제</string>
<string name="modify">수정</string>
<string name="close">닫기</string>
<string name="next">다음</string>
<string name="complete">완료</string>
```

## 파일 위치

```
app/src/main/res/values/strings.xml
```

## 상세 문서

컨벤션: [string-resource-convention.md](../../../.docs/conventions/string-resource-convention.md)

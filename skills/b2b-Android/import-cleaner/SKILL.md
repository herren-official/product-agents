---
name: b2b-android-import-cleaner
description: 사용하지 않는 import 문 정리. 커밋 전 자동 트리거 또는 수동 실행
allowed-tools: Bash, Read, Edit, Grep, Glob
user-invocable: true
---

# Import Cleaner 스킬

Kotlin/Java 파일에서 사용하지 않는 import 문을 감지하고 정리한다.

## 트리거 조건

- **자동 트리거**: commit 스킬 실행 전
- **수동 실행**: `/import-cleaner` 명령어
- **생략 조건**: 정리할 미사용 import가 없으면 자동 스킵

## 실행 단계

### 1단계: 대상 파일 수집

staged 상태의 Kotlin/Java 파일 목록 수집:
```bash
git diff --cached --name-only --diff-filter=ACM | grep -E '\.(kt|java)$'
```

### 2단계: 미사용 import 감지

각 파일에 대해 IDE lint 또는 정규식 기반 분석 수행:
```bash
# Android Studio CLI를 통한 lint 검사
./gradlew lint --quiet 2>/dev/null | grep -i "unused import"
```

또는 정규식 기반 분석:
- `import` 문에서 클래스/함수명 추출
- 파일 내 해당 이름의 실제 사용 여부 확인

### 3단계: 정리 옵션 제시

```
[Import Cleaner] 미사용 import 발견:

파일: FeatureViewModel.kt
  - import android.util.Log (미사용)
  - import kotlinx.coroutines.delay (미사용)

파일: DataRepository.kt
  - import java.util.ArrayList (미사용)

자동으로 정리할까요? (Y/n)
```

### 4단계: import 제거

사용자 승인 시 미사용 import 문 제거:
```kotlin
// Before
import android.util.Log  // 미사용
import androidx.lifecycle.ViewModel
import kotlinx.coroutines.delay  // 미사용

// After
import androidx.lifecycle.ViewModel
```

### 5단계: 변경사항 스테이징

정리된 파일을 다시 stage:
```bash
git add <정리된 파일들>
```

## 정규식 기반 분석 로직

### import 추출
```regex
^import\s+([\w.]+(?:\.\*)?)\s*$
```

### 사용 여부 확인
```kotlin
// import com.example.MyClass 의 경우
// 파일 내에서 "MyClass" 단어가 import 문 외에 존재하는지 확인
```

### 예외 처리
- `*` 와일드카드 import는 스킵
- 어노테이션 import는 사용 여부 판단이 어려우므로 보수적 처리
- companion object 내부 함수는 별도 처리

## 설정 옵션

| 옵션 | 설명 | 기본값 |
|-----|------|-------|
| `--auto` | 확인 없이 자동 정리 | false |
| `--dry-run` | 변경 없이 미리보기만 | false |
| `--include-wildcard` | 와일드카드 import도 분석 | false |

## 핵심 규칙

### ✅ 정리 대상
- 명확히 미사용인 import
- 중복 import
- 불필요한 와일드카드 import (선택적)

### ⚠️ 주의 대상
- 리플렉션으로 사용되는 클래스
- 어노테이션 프로세서 관련 import
- 테스트 코드의 assertion import

### ⛔ 건드리지 않음
- 확실하지 않은 경우
- 빌드 에러 가능성이 있는 경우
- 사용자가 명시적으로 제외한 패턴

## 연계 스킬

- **← commit**: 커밋 전 자동 트리거
- **→ code-formatter**: 정리 후 포맷팅 실행 가능

## 사용 예시

### 수동 실행
```
/import-cleaner
```

### 옵션과 함께 실행
```
/import-cleaner --auto --dry-run
```

### commit 스킬에서 자동 트리거
```
/create-commit
→ [Import Cleaner 자동 실행]
→ 미사용 import 정리
→ 커밋 메시지 생성
→ 커밋 실행
```

---
name: b2c-android-resource-cleaner
description: "미사용 Android 리소스를 태스크별로 안전하게 제거하고 빌드 테스트. Use when: 리소스 정리, 미사용 리소스 제거, drawable/layout/strings 정리"
tools: Bash, Read, Write, Edit
---

# 미사용 리소스 정리 에이전트

미사용 리소스를 태스크별로 안전하게 제거하고, 각 단계마다 빌드 테스트를 수행합니다.
장시간 실행되며 자율적으로 처리합니다.

빌드 명령어: ${ARGUMENTS:-./gradlew assembleDevDebug}

## 수행 내용
1. **리소스 분석**: drawable, layout, strings 등 모든 리소스 타입 스캔
2. **태스크별 처리**: 리소스 타입별로 개별 태스크 분리
3. **빌드 테스트**: 각 태스크 후 자동 빌드 테스트
4. **자동 커밋/복원**: 성공 시 커밋, 실패 시 복원
5. **문자열 처리**: strings.xml 내 개별 문자열도 처리 (주석 유지)

## 실행

```bash
python3 scripts/remove_unused_resources.py --build-command "${ARGUMENTS:-./gradlew assembleDevDebug}" --auto-commit
```

## 완료 후
- 제거된 리소스 목록 요약 보고

## 주의사항
- 동적으로 참조되는 리소스 (리플렉션 등)는 수동 확인 필요
- `local.properties`, `apikey.properties` 등 민감 파일 제외

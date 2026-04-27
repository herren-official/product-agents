---
name: b2b-web-folder-structure
description: 도메인 기반 폴더 구조와 3Depth 추상화 레벨 규칙. 컴포넌트나 페이지 생성 요청 시 자동으로 참조됨.
user-invocable: false
---

# 폴더 구조 규칙

이 skill은 컴포넌트/페이지 생성 시 자동으로 적용됩니다.

## 상세 규칙

전체 규칙은 [FOLDER_STRUCTURE_CONVENTIONS.md](/.docs/conventions/FOLDER_STRUCTURE_CONVENTIONS.md)를 참조하세요.

## 핵심 요약

### 도메인 폴더 구조

```
src/domains/{domain}/
├── index.tsx              # 1depth - 페이지 진입점
├── ui/                    # 공통 UI 컴포넌트
├── hooks/                 # 도메인 공통 훅
├── {feature}/             # 기능별 하위 도메인
│   ├── index.tsx          # 1depth - 기능 진입점
│   ├── ui/                # UI 컴포넌트 (2depth)
│   ├── components/        # UI components (3depth)
│   ├── state/             # Recoil atoms, selectors
│   ├── hooks/             # Custom hooks
│   ├── api/               # API 호출
│   ├── types/             # 타입 정의
│   └── constants/         # 상수
```

### 3Depth 추상화 레벨

| Depth | 책임 | 위치 | 특징 |
|-------|------|------|------|
| **1** | 페이지 전체 구조 | `index.tsx` | 레이아웃 구성, 하위 컴포넌트 조합 |
| **2** | UI 단위, 분기처리, 이벤트 | `ui/` | 비즈니스 로직, 상태 관리, 이벤트 핸들링 |
| **3** | 정적 UI, 스타일 | `components/` | 순수 프레젠테이션, Props만 사용, 재사용 가능 |

### 적용 원칙

1. **3depth 초과 금지** - 최대 3depth까지만 허용
2. **책임 분리** - 각 depth별 책임 명확히 구분
3. **재사용성** - 3depth 컴포넌트는 Props로만 데이터 전달
4. **유연한 적용** - 단순한 경우 2depth로 충분

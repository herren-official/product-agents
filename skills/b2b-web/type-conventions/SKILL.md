---
name: b2b-web-type-conventions
description: TypeScript에서 interface와 type의 사용 기준. 타입 정의 시 자동으로 참조됨.
user-invocable: false
---

# TypeScript 타입 규칙

이 skill은 타입 정의 시 자동으로 적용됩니다.

## 상세 규칙

전체 규칙은 [TYPE_CONVENTIONS.md](/.docs/conventions/TYPE_CONVENTIONS.md)를 참조하세요.

## 핵심 요약

### Interface 사용 (2가지 경우만)

1. **객체 형태의 데이터 모델**
   ```tsx
   interface CustomerResponseDto {
     customerId: number
     name: string
   }

   interface Employee {
     employeeNo: number
     name: string
   }
   ```

2. **Props**
   ```tsx
   interface ButtonProps {
     children: React.ReactNode
     onClick?: () => void
   }
   ```

### Type 사용 (나머지 모든 경우)

| 용도 | 예시 |
|------|------|
| Union | `type Status = 'pending' \| 'success'` |
| 함수 | `type OnClickHandler = () => void` |
| 유틸리티 조합 | `type PartialCustomer = Partial<Customer>` |
| 튜플 | `type Coordinate = [number, number]` |
| Primitive 별칭 | `type ID = number` |
| 조건부/매핑 타입 | `type Nullable<T> = T \| null` |

### 네이밍 규칙

- **Interface**: PascalCase + 용도 접미사
  - `CustomerResponseDto` (API 응답)
  - `ButtonProps` (Props)
  - `LoginFormData` (폼 데이터)

- **Type**: PascalCase
  - `ButtonVariant`
  - `OnClickHandler`

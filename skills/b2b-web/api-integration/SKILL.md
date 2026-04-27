---
name: b2b-web-api-integration
description: 여러 Notion API 문서를 프론트에 반영하는 작업. Notion/Swagger/로컬 DTO 3-way 대조로 불일치를 자동 탐지하고 구현·테스트 계획까지 산출. /api-integration 실행 시 활성화.
user-invocable: true
---

# API Integration

여러 Notion API 명세를 **프론트엔드 코드에 반영**하는 작업 전체를 가이드하는 스킬.

## 명령어

```
/api-integration {notion-url-1} {notion-url-2} ...
/api-integration {backlog-notion-url} --swagger https://crm-devN.gongbiz.kr
```

## 왜 필요한가

Notion 문서만 보고 구현하면 놓치는 케이스:

- **Notion ↔ Swagger 불일치**: Notion은 "완료(개발배포O)"인데 실제 서버엔 안 깔림
- **내부 DTO 누락**: `List<SomeRequest>?` 타입명만 있고 내부 필드가 문서에 없음
- **API간 포맷 불일치**: 저장 API는 객체, 검색 API는 문자열 (이번 작업의 `optionValue` 버그)
- **Notion 자동생성 대비 부족**: data-contracts.ts가 구 스키마로 남아있어 새 필드 미반영

→ Swagger 스펙이 **진실의 원천**이므로 반드시 교차 검증.

## 차별점

| 스킬 | 초점 |
|------|------|
| `review-api` | 단일 API **깊이 리뷰** (정책 · 사용처 · 이슈 도출) |
| `impact-analysis` | 기능 **서비스 전반 연쇄 영향** |
| **이 스킬** | **여러 API를 프론트에 반영**하는 전체 사이클 (분석 → 구현 → 테스트 → 백엔드 피드백) |

---

## 5단계 흐름

### Phase 0: 입력 수집
1. Notion URL 리스트 파싱 (`mcp__claude_ai_Notion__notion-fetch` 병렬 호출)
2. Swagger JSON 다운로드 (`curl https://crm-devN.gongbiz.kr/v3/api-docs -o /tmp/swagger.json`)
3. 현재 로컬 `src/libs/apiV2/modules/data-contracts.ts` 상태 스냅샷

### Phase 1: 3-way 대조
각 API에 대해 Notion · Swagger · 로컬 TS 타입을 나란히 비교.

**Swagger에서 DTO 추출하는 one-liner**:
```bash
python3 -c "
import json
d = json.load(open('/tmp/swagger.json'))
s = d['components']['schemas'].get('SCHEMA_NAME')
print(json.dumps(s, ensure_ascii=False, indent=2))
"
```

**전체 스키마명 검색**:
```bash
python3 -c "
import json
d = json.load(open('/tmp/swagger.json'))
names = [k for k in d['components']['schemas'] if 'KEYWORD' in k]
print(names)
"
```

**특정 필드가 어디에 있는지 검색**:
```bash
python3 -c "
import json
d = json.load(open('/tmp/swagger.json'))
for name, s in d['components']['schemas'].items():
    if 'FIELD_NAME' in s.get('properties', {}):
        print(name)
"
```

### Phase 2: 불일치 리포트

각 불일치를 3단계로 분류:

| 심각도 | 의미 | 조치 |
|---|---|---|
| 🔴 CRITICAL | 런타임 400/500 유발 | **코드/백엔드 즉시 수정** |
| 🟡 MINOR | 문서만 빠짐 / nullable 차이 | 보완 요청 또는 방어 코드 |
| 🟢 OK | 3-way 모두 일치 | 통과 |

**리포트 포맷**:
```markdown
| # | API | Notion | Swagger | 로컬 TS | 판정 |
|---|---|---|---|---|---|
| 1 | POST /filters | optionValue: Object | Object | Object | 🟢 |
| 2 | POST /customers/chart | (미기재) | **String** | Object | 🔴 |
```

### Phase 3: 실행 계획

**3가지 버킷으로 분류**:

1. **프론트에서 수정 가능** → 로컬 DTO · 호출 코드 업데이트
2. **백엔드 수정 필요** → 요청 메시지 초안 작성 (Swagger 스니펫 첨부)
3. **문서 보완 필요** → Notion 페이지에 누락 필드 추가 요청

### Phase 4: 구현 + 테스트

- 로컬 타입 업데이트
- 호출부 수정
- MSW 핸들러 · 시나리오 · mock 데이터 보강
- 유닛 테스트 (핵심 변환 로직)
- 타입 체크 + lint + jest

### Phase 5: 백엔드/문서 피드백 전달

Phase 2에서 🔴/🟡로 분류된 항목 중 백엔드/기획 조치 필요한 것을 정리하여 사용자에게 전달.

---

## 백엔드 수정 요청 메시지 템플릿

```markdown
**제목: [API명] [필드명] DTO 불일치 수정 요청**

### 현상
`{METHOD} {URI}` 호출 시 [간단 설명].

에러(재현):
```
{에러 스택 / JSON parse error}
```

### 근거 — Swagger 스펙 ({env})
[OpenAPI JSON]({swagger-url}) 확인 결과:

**`{DTO-A}.{field}`** (A API)
```json
{Swagger JSON fragment}
```

**`{DTO-B}.{field}`** (B API)
```json
{Swagger JSON fragment}
```

불일치: [차이 요약]

### 요청
1. **코드 수정**: [변경 사항]
2. **문서 보완**: [Notion 페이지 링크] — [누락 내용]

### 영향
- 백엔드 수정 완료 시 프론트는 별도 변경 없이 동작
- [그 외 영향]
```

---

## 이번 작업(GBIZ-26052)에서 검증된 실전 예시

### 발견된 이슈
1. **🔴 `POST /customers/chart`의 `CustomerCustomFilterConditionRequest.optionValue`**
   - Notion: 내부 DTO 미기재
   - Swagger: `string` (구 포맷)
   - 기대: `Object {id, name}` (26.4.16 저장 API 변경 반영 안 됨)
   - 조치: 백엔드 수정 요청

2. **🟡 `GET /customers/{customerNo}`의 `isDontSend`**
   - Notion: "추가" 표기
   - Swagger(dev6): 없음 (배포 대기)
   - 조치: `?? false` 방어 코드 + 백엔드 배포 확인

3. **🟡 `blacklist` vs `isBlacklist` 필드명**
   - Swagger: `blacklist`
   - 프론트: v1의 `black === 1`로 계산
   - 조치: 별도 리팩터링 백로그

### 배운 점
- **Notion 문서가 항상 Swagger와 일치하지 않음** → Swagger가 최종 진실
- **관련 API끼리 DTO 공유 여부 확인 필수** — 하나만 바뀌면 다른 쪽에서 터짐
- **Jackson(Kotlin)은 enum 필드에 null 거부** → `sortOrder: null` 대신 필드 생략
- **Period `type: 'ALL'`은 backend 관점에서 null** → 명시 객체 전송하면 거부

---

## 산출물 디렉토리

```
.docs/api-integration/{featureName}/
├── mismatch-report.md    # Phase 2 결과
├── backend-request.md    # Phase 5 백엔드 요청 메시지
└── notion-doc-gaps.md    # Notion 문서 보완 요청
```

프론트 구현은 일반 브랜치 작업으로 진행 (MSW/테스트 포함).

---

## Claude 행동 규칙

1. **Swagger가 진실** — Notion과 충돌 시 Swagger 기준으로 구현하되, 차이는 리포트에 명시
2. **불일치 발견 시 즉시 공유** — 구현하다 발견된 불일치는 별도 섹션에 누적 기록
3. **DTO 공유 의심** — 같은 이름의 필드가 여러 DTO에 있으면 전부 대조 (이번 `optionValue` 사례)
4. **enum은 nullable 주의** — 백엔드 Kotlin enum은 대부분 strict → null 대신 필드 생략
5. **MSW는 실제 응답 모사** — 검증된 Swagger 스펙 그대로 반영 (Notion 기반 X)
6. **백엔드 요청은 근거 첨부** — 스웨거 JSON 스니펫 + 재현 에러 + 영향 범위

---
description: shadcn 컴포넌트 규칙 가드
globs:
  - "**/*.tsx"
  - "**/*.jsx"
---

# shadcn 컴포넌트 가드

## 절대 금지

- `components/ui/*` 소스 파일을 직접 수정하지 않는다
- 컴포넌트 기본 스타일을 className으로 덮어쓰지 않는다

## 스타일 변경이 필요한 경우 (우선순위)

1. variant prop 활용
2. semantic token 활용
3. CSS variable 조정
4. 위 방법으로 불가능하면 사용자에게 확인

## 상세 규칙

styling·forms·composition 상세 규칙이 필요할 때만 `.claude/skills/shadcn/rules/`에서 해당 주제 파일 하나를 읽는다. 디렉토리 전체를 읽지 않는다.

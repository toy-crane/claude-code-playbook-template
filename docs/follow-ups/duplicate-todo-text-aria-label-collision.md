# 텍스트가 같은 Todo 두 개의 체크박스/삭제 버튼 접근성 이름이 충돌한다

**Symptom**: `components/todo-item.tsx`에서 체크박스와 삭제 버튼의
`aria-label`을 `${todo.text} 완료` / `${todo.text} 삭제`처럼 텍스트로만
만든다. 텍스트가 같은 Todo가 두 개 이상 있으면 두 항목의 접근성 이름이
완전히 동일해져 구분할 수 없다.

**Observed evidence**: `code-review` 스킬 리뷰(2026-08-18, `feat: Todo 앱
구현` 커밋 직후)에서 지적됨. "우유 사기"를 두 번 추가하면
`getByRole('checkbox', { name: '우유 사기 완료' })` 같은 쿼리가 항목을
하나로 특정하지 못하고(테스트/자동화에서는 다중 매치 에러), 스크린리더
사용자도 두 체크박스/버튼을 동일한 이름으로만 듣게 된다.

**Suspected cause**: 접근성 이름을 `todo.id`가 아니라 `todo.text`에서만
파생시키기 때문. 스펙(`docs/specs/todo-app/spec.md`)이 중복 Todo 허용
여부나 중복 시 표시 방식을 다루지 않아, 고유 식별자를 이름에 노출할지
(가독성 저하) 목록 위치 정보를 추가할지(항목 추가/삭제 시마다 이름이
바뀜) 등은 기술적 판단만으로 정하기 어렵다.

**What was tried**: 이번 세션에서는 고치지 않았다. 리뷰가 지적한 다른
두 건(새로고침 시 저장 경쟁 상태, `<html lang="en">` 불일치)만 수정해
커밋했다.

**Proposed next step**: 중복 Todo 텍스트를 허용할지, 허용한다면 접근성
이름을 어떻게 구분할지(예: 숨김 순번 접미사, `todo.id` 기반 `aria-describedby`
등) `shape-idea`로 확인한 뒤 `todo-item.tsx`의 `aria-label`을 갱신한다.

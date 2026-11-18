# setup-supabase로 만든 앱에서 사용자가 자기 profile의 email을 API로 바꿀 수 있음

**Symptom**: `setup-supabase` 실행 결과에 따라, 로그인한 사용자가 REST API로 자기 `profiles.email`을 임의 값으로 바꿀 수 있다. 그러면 `/settings`에 바뀐 이메일이 보이고 "email은 가입 시 Auth 이메일을 복사한 값" 보장이 깨진다.

**Observed evidence**: 2026-11-19 `docs/specs/setup-supabase-auth-flow/` eval 2회차(Sonnet 실행, Opus 검증, 호스팅 프로젝트 `feedme-clone`). 사용자 본인 토큰으로 `PATCH <url>/rest/v1/profiles?id=eq.<self>`에 `{"email":"x@evil.com"}`을 보내자 성공했다. 같은 eval 1회차 결과물은 `created_at`·`email` 쓰기를 거부했다. 즉 실행마다 결과가 다르다.

**Suspected cause**: 2회차 마이그레이션은 `grant update (display_name)`만 추가하고, Supabase가 `anon`·`authenticated`에 기본으로 주는 테이블 전체 권한을 회수하지 않았다(추정, Opus 검증자가 권한 목록으로 확인). 스킬 본문은 "/settings에서 수정 가능한 필드는 표시 이름 하나"라고만 하고, DB 수준에서 다른 컬럼 쓰기를 막으라고는 하지 않는다.

**What was tried**: 수정하지 않았다. AGENTS.md 검증·리뷰 예산상 spec이 요구하지 않은 보안 하드닝이라 범위 밖으로 두었다.

**Proposed next step**: `setup-supabase` 본문의 profiles 지시에 "소유자는 DB 수준에서도 표시 이름만 쓸 수 있고 email·타임스탬프는 쓸 수 없다"를 추가할지 결정하고, 추가한다면 깨끗한 템플릿에서 스킬을 실행해 본인 토큰의 email PATCH가 거부되는지 확인한다.

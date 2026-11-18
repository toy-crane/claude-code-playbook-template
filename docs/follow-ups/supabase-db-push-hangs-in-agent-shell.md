# 에이전트 셸에서 supabase db push가 "Initialising login role..."에서 멈춤

**Symptom**: Claude Code 에이전트(메인 세션, 서브에이전트 모두)가 실행한 `supabase db push --linked`가 "Initialising login role..." 뒤로 진행하지 않는다. 같은 명령을 사용자가 Terminal 패널에서 직접 실행하면 정상적으로 마이그레이션이 적용된다.

**Observed evidence**: 2026-11-19, macOS, Supabase CLI 2.109.1, 대상 `feedme-clone`. 멈춘 프로세스 아래에 `/usr/bin/security find-generic-password -s Supabase CLI -wa supabase`가 끝나지 않고 남아 있었다. 같은 셸에서 `supabase projects list`, `migration list --linked`, `db query --linked`는 정상이고, 풀러 포트 5432·6543 연결도 열려 있었다.

**Suspected cause**: `db push`만 macOS 키체인 항목을 읽는 경로를 타고, 에이전트가 띄운 프로세스에서는 키체인 접근 허용 창에 응답할 수 없어 대기하는 것으로 추정한다.

**What was tried**: eval 1회차 에이전트는 같은 SQL을 `db query --linked -f`로 적용하고 마이그레이션 이력을 직접 넣어 우회했다. 2회차는 사용자가 터미널에서 `supabase db push --linked`를 직접 실행해 해결했다. 근본 원인은 그대로다.

**Proposed next step**: 사용자 터미널에서 키체인 창이 뜰 때 "항상 허용"을 고른 뒤 에이전트 셸에서 `supabase db push --linked --dry-run`이 끝나는지 확인한다. 그래도 멈추면 `setup-supabase`의 "비밀값이 필요해 CLI 단계가 실패하면 사용자 터미널로 넘긴다" 규칙에 '멈춤'도 포함할지 정한다.

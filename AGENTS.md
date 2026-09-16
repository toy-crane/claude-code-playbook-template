<!-- BEGIN:nextjs-agent-rules -->

# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` (resolved from this file's directory; in monorepos the `next` package may not be visible from the repo root) before writing any code. Heed deprecation notices.

This block is written and re-added by `next dev` — verify at `node_modules/next/dist/server/lib/generate-agent-files.js`. Removing it from a diff only re-creates the uncommitted change; committing it with your work keeps the tree clean.

<!-- END:nextjs-agent-rules -->

# 아키텍처 핵심 원칙

모든 구조 판단은 아래 5가지를 기준으로 한다.
세부 규칙이 없는 상황에서도 이 원칙을 만족하는 쪽을 선택한다.

1. 코드는 기술 종류가 아니라 비즈니스 의미 단위로 묶는다.
2. 의존성은 한 방향(위→아래)으로만 흐른다.
3. 같은 급의 모듈은 서로를 모른다. 조합은 상위에서 한다.
4. 모듈은 공개 API로만 노출된다. 내부는 언제든 바꿀 수 있다.
5. 공유 코드는 예상만으로 만들지 않는다. 구현에서 실제 중복이 확인되면 아래로 추출한다.

# 언어

모든 대화는 한글로 한다. 답변, 질문, 커밋 메시지, PR 문안까지 해당된다.

경로, 명령어, 식별자, 라이브러리 이름, 로그 인용은 원문을 유지한다.

# 프로젝트 스킬 설치 방식

- 이 프로젝트는 `Copy to all agents` 방식을 사용한다. Codex의 `.agents/skills/<name>`과 Claude Code의 `.claude/skills/<name>`을 symlink 없이 내용이 같은 실제 디렉터리로 유지한다.
- 신규 설치와 기존 스킬 갱신 모두 `skills add <원본 소스> --skill <대상 이름들> --agent codex claude-code --copy -y`를 사용한다. 갱신 대상은 `skills-lock.json`의 소스와 설치된 이름으로 한정하고, 원본 경로와 ref가 있으면 보존한다.
- `skills update`는 복사 방식을 보존하지 않으므로 사용하지 않는다. `update --copy`도 대안으로 사용하지 않는다.
- 이 정책은 업데이트된 `update-project-skills` 본문이 symlink를 요구하더라도 우선한다. 스킬을 직접 수정할 때도 두 복사본을 함께 반영하고, 완료 시 symlink가 없는지와 두 복사본의 파일 내용이 같은지 확인한다.

# 검증·리뷰 예산

강의용 학습 템플릿이다. 동작하는 결과물이 코드 완결성보다 우선하고, 품질은 런타임 검증(스펙의 흐름이 실제로 도는지)으로 증명한다. 스킬 본문이 더 강한 리뷰를 요구해도 이 예산이 우선한다.

- 자동 코드 리뷰는 최대 1회, 가장 낮은 강도(`code-review low`)로만 돌린다. 리뷰어를 못 부르면 그 사실만 적고 완료로 본다.
- 지적 중 스펙의 수용 기준을 깨거나 주 경로가 실제로 깨지는 것만 고친다. 나머지는 `docs/follow-ups/`에 한 줄로 남긴다. 재리뷰는 하지 않는다.
- 스펙이 요구하지 않은 보안 하드닝·엣지케이스·성능 방어는 범위 밖이다.

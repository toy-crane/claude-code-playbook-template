---
name: setup-supabase
description: Set up or resume a minimal Supabase Cloud integration for an application, with optional email/password or Google authentication, the official profiles pattern, owner-only authorization, and a protected settings page. Use when a project needs Supabase connected or a learner-friendly Supabase Auth setup without broader backend features or production hardening.
---

# Setup Supabase

Build the smallest working Supabase Cloud path that fits the existing application.
This skill coordinates decisions, delegates implementation details to current
official guidance, and verifies runtime behavior. Do not copy commands, SQL,
framework snippets, or dashboard click paths into this skill.

## Inspect before changing anything

- Identify the framework, installed version, router, runtime, and whether the app
  uses server-side rendering.
- Inspect existing environment variables, Supabase clients, Auth code, migration
  structure, Cloud project references, and profile data model.
- Reuse compatible work. Do not overwrite existing configuration or create a
  duplicate Cloud project, client, profile table, trigger, or policy.
- If the target Cloud project is ambiguous, stop and ask the user to select it.

## Prepare official Supabase skills

Before making any Supabase decision or change, consult the current
[Supabase Agent Skills documentation](https://supabase.com/docs/guides/ai-tools/ai-skills).

- Verify that the required skills come from Supabase's official source and are
  current. Install or update only the relevant Supabase skills at project scope
  using the method currently documented by Supabase. The current required pair
  is `supabase` and `supabase-postgres-best-practices`; reconcile that list with
  the official documentation at execution time.
- Read the official `supabase` skill before any Supabase work. Before changing
  tables, migrations, triggers, grants, or RLS, also read the current official
  database best-practices skill. The documentation is authoritative if names or
  installation details change.
- Do not substitute community skills, update unrelated skills, or reproduce the
  official skills inside this skill.
- If the official skills cannot be verified, installed, updated, or read, report
  the blocker and stop instead of relying on model memory.

## Choose the setup scope

Ask whether the user wants Auth.

If Auth is not wanted, connect or reuse the Supabase Cloud project, expose only
the client-safe connection values the application needs, verify the minimal
connection through an existing safe path, and stop. Do not create profiles, Auth
UI, RLS policies for profiles, or `/settings`.

If Auth is wanted, offer only these choices and implement only the selected one:

- **Email and password** — the default for the course.
- **Google** — an optional recommendation when the user can complete the Google
  OAuth prerequisites during the session.

For email and password, ask whether email confirmation should be enabled. Recommend
disabling it for the time-bounded course because the hosted default mail service
can block or delay the primary path. Never change that setting without the user's
choice. When confirmation remains enabled, include the confirmation callback in
the setup and completion check. Do not add custom SMTP.

Before proceeding with Google, confirm that the user can supply or configure the
required Google OAuth credentials and that the actual local and deployed origins
are known. If not, offer to switch to email and password or defer Google. Keep
Google optional even when recommended.

## Configure Supabase Cloud and the application

Follow the current official documentation and the loaded official skills rather
than a memorized procedure.

- Reuse or create one hosted project and configure only what the chosen path
  requires.
- Use the Project URL and a publishable client key in client-visible application
  configuration. Never expose a secret or service-role key to client code or
  commit credentials.
- When Auth is selected, align Site URL, allowed redirects, provider settings,
  and callback behavior with the environments that will actually be exercised.
- Follow the current framework-specific official integration. In server-rendered
  applications, make authorization decisions from server-verified identity and
  preserve the official cookie-based session refresh behavior; do not authorize
  from client state or an unverified session user alone.
- Do not require the Supabase MCP server, an agent plugin, local Supabase, Docker,
  or deployment automation. Use an existing migration workflow when present, but
  do not introduce a local database workflow solely for this setup.

## Add the minimal authenticated experience

When Auth is selected:

- Support sign-up or first sign-in, sign-in, sign-out, and session persistence
  for the chosen method.
- Apply Supabase's current official user-management profile pattern. Tie profiles
  to Auth users, keep profile lifecycle consistent with user creation and deletion,
  and enable owner-only access with RLS.
- Reuse an existing profile name field. If none exists, add only one editable
  display name field. Do not add avatars, bios, roles, or public profiles.
- Protect `/settings`. It should expose only the minimal profile view and edit
  behavior needed to prove the authenticated path.

Use the current official [User Management](https://supabase.com/docs/guides/auth/managing-user-data),
[RLS](https://supabase.com/docs/guides/database/postgres/row-level-security),
[SSR Auth](https://supabase.com/docs/guides/auth/server-side/creating-a-client),
[Password Auth](https://supabase.com/docs/guides/auth/passwords), and
[Google Auth](https://supabase.com/docs/guides/auth/social-login/auth-google)
guides only when their branch applies.

## Verify observable behavior

Do not treat files, policies, or UI presence as proof of completion. Exercise the
runtime path that was selected.

Without Auth, verify the application reaches the intended Cloud project through
the client-safe configuration and confirm that no Auth-only artifacts were added.

With Auth, verify all applicable outcomes:

- the selected method completes sign-up or first sign-in, sign-in, and sign-out;
- the session survives a refresh;
- a profile is created for a new user;
- the user can read and update their own profile;
- an unauthenticated user and another authenticated user cannot read or update it;
- `/settings` rejects unauthenticated access; and
- after sign-out, `/settings` is inaccessible again.

Use two users or an equivalent check supported by the official skills to prove
the owner-only boundary. If email confirmation is enabled, verify that flow too.

## Stop and report honestly

Pause when the next step requires user login, consent, or secret entry. Also stop
when the official skills are unavailable, the target Cloud project is unclear,
or existing configuration conflicts cannot be resolved safely. State where work
stopped and the single next user action needed; do not claim completion.

At the end, report the selected choices, official skills and documentation used,
Cloud and repository changes, runtime evidence, and any remaining user action.

Keep password reset, Magic Link, OTP, phone Auth, MFA, SSO, extra providers,
RBAC, account deletion, Storage, custom SMTP, and general production hardening
outside this setup.

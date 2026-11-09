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
  or deployment automation. The Supabase CLI is required only to apply schema
  changes to the hosted project, as described below. Use an existing migration
  workflow when present, but do not introduce a local database workflow solely
  for this setup.

## Prepare the Supabase CLI before schema changes

Apply tables, triggers, grants, and RLS to the hosted project yourself through
the Supabase CLI, so the remote migration history matches the repository.
Handing migration SQL to the user to paste into the dashboard leaves that
history out of step, so do not use it as the path. Follow the current
[Supabase CLI documentation](https://supabase.com/docs/guides/local-development/cli/getting-started)
at execution time for installing, signing in, linking, and pushing migrations.

- Before the first schema change, confirm that the CLI runs and is signed in
  with a real authenticated call, such as listing the account's projects. A
  binary on the path or a token file is not proof.
- When the CLI is missing, install it with the method the documentation gives
  for this platform or through the project's package manager.
- When it is not signed in, ask the user to run the CLI's browser sign-in once
  in their own terminal and to tell you when it is done. Sign-in belongs to the
  user.
- After sign-in, link the repository to the selected hosted project and push
  the migrations yourself, first without a database password. A signed-in CLI
  normally reaches the hosted database through its own temporary login role, so
  do not ask for, reset, or hand off the database password in advance, and do
  not hand linking to the user because nobody knows the generated password.
  Then confirm that the remote migration history lists the migrations.
- Only when a CLI step you ran actually fails for lack of a database password,
  token, or other secret, show the user the CLI's message and ask them to enter
  the value in their own terminal; never take it through the conversation.
  Continue from that step once they are done.
- Creating the CLI's project folder for migrations is part of this step.
  Starting a local Supabase stack or Docker is not.

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

## Start Auth screens from the official UI block

When Auth is selected, build sign-up, sign-in, sign-out, the auth callback, and
session refresh from Supabase UI Library's official shadcn block for the
selected method instead of writing them from scratch. Repeated runs then share
one structure, and the screens use the project's shadcn components and tokens.
For Next.js, use [Password-based Auth](https://supabase.com/ui/docs/nextjs/password-based-auth)
for email and password and [Social Auth](https://supabase.com/ui/docs/nextjs/social-auth)
for Google. For another framework, use the UI Library's matching block when one
exists. When no block fits the framework or the project does not use shadcn/ui,
build the same flow from the official guides above.

The block is written for a generic project, not this one. Before installing it,
read the block's current documentation and its registry item to learn which
files, dependencies, shadcn components, and environment variables it brings.
Then adapt it to the project as it stands at execution time:

- Check every framework file convention the block relies on against the
  installed framework version's own documentation, and use what that version
  expects. Blocks can lag behind framework releases, for example in where
  request-time session refresh lives.
- Merge the block into the existing Supabase clients, environment variable
  names, routes, layouts, and shadcn configuration instead of letting the
  install overwrite them or add duplicates. Run the shadcn CLI through the
  project's package manager, and let shared components resolve to the
  project's own shadcn style and tokens.
- Keep the block inside this setup's scope. Use the selected provider instead
  of the block's example provider. Limit its route protection to `/settings`
  instead of redirecting every unauthenticated request. Send post-auth
  redirects to real app destinations instead of the block's example page. Keep
  email-confirmation pages and routes only while confirmation stays enabled,
  and remove screens for excluded features such as password reset.

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
when the official skills are unavailable, the Supabase CLI cannot be installed
or signed in, the target Cloud project is unclear, or existing configuration
conflicts cannot be resolved safely. State where work
stopped and the single next user action needed; do not claim completion.

At the end, report the selected choices, official skills, documentation, and UI
block used, how the block was adapted to the project, Cloud and repository
changes, runtime evidence, and any remaining user action.

Keep password reset, Magic Link, OTP, phone Auth, MFA, SSO, extra providers,
RBAC, account deletion, Storage, custom SMTP, and general production hardening
outside this setup.

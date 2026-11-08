# Password reset email

## User-visible outcomes

- A user who requests a reset receives an email with a one-time link.
- The link opens a page where they set a new password.

## Approved scope

The reset request sends one email through Resend from `no-reply@acme.test`.

## Setup before implementation

- Resend sending domain `acme.test` verified (reset email): the domain shows Verified in the Resend console
- Resend API key (reset email): a direct call to the Resend API with the key succeeds

## Observable acceptance criteria

- Requesting a reset for a known address delivers one email within a minute.
- The link works once and expires after 30 minutes.

## Settled constraints and rationale

- Resend is the mail provider; the team already uses it for receipts.

## Assumptions

None.

## Off-limits

- Changing the sign-in flow.

## Deferred points

None.

## Remaining risks

None.

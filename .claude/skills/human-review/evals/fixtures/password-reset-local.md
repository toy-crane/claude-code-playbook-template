# Available password-reset evidence

- Local request form renders and validates a syntactically valid email.
- A fake mail adapter receives a reset request with a local-only token.
- Production delivery was not run because credentials are unavailable.
- Production expiry and one-time-use behavior were not observed.

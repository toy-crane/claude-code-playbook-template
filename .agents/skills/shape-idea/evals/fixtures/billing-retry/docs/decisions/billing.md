# Billing

## Decisions

- A failed card charge is retried at most three times, at 1 hour, 24 hours, and
  72 hours after the failure. A fourth automatic attempt is never made.
- A charge that fails because the card is permanently declined stops the
  schedule immediately instead of consuming the remaining attempts.

## Why

Retry spacing was tuned against issuer soft-decline recovery rates. Repeating
the evaluation per feature produced inconsistent schedules across surfaces.

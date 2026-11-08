# Data ownership

## Decisions

- The Billing module alone writes the `invoices` table.

## Why

Two writers produced conflicting invoice totals.

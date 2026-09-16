# Invoice refactor replay

Named change: `invoice-readability-demo`

The request permits only internal readability changes. Public inputs, outputs,
side effects, error behavior, logging, and operational configuration must remain
unchanged.

The supplied replay covers normal totals, discounts, empty invoices, rounding
boundaries, invalid coupons, and downstream event payloads. Every before and
after output is identical. The diff contains no configuration, logging, event,
or dependency change.

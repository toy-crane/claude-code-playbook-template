# Digest schedule

## User-visible outcomes

- A user can receive one daily digest email instead of an immediate
  notification for every event.
- A user picks the hour the digest arrives, in their own timezone.
- A user can see, inside the digest, everything that happened since the
  previous one.

## Decision contracts this work depends on

- `docs/decisions/notifications.md`: how events are grouped and suppressed.

## Approved reference

- `prototype.html`: the approved digest settings screen and the digest email
  body, in their default and empty states.

## Approved scope

### Digest settings

The preferences screen gains a digest section: a switch that turns the daily
digest on, and an hour picker that appears once it is on. The user can also
turn notifications off per target from the same screen.

### Digest contents

At the chosen hour, every event recorded since the previous digest is
collected and sent as one email. Each event keeps its target label so the user
can tell where it came from. An hour with no events sends nothing.

## Observable acceptance criteria

- Turning the digest on and choosing an hour persists across a reload.
- The digest sent at hour H contains exactly the events recorded since the
  previous digest.
- A user can turn notifications off per target from the preferences screen.
- An interval with no events produces no email.

## Settled constraints and rationale

- The digest includes events from muted targets. Muting suppresses the
  immediate notification only; the digest stays a complete record of the
  interval, so a user who mutes a noisy target does not silently lose its
  history.
- One digest per user per interval. Splitting it per target would reproduce
  the notification volume the digest exists to reduce.

## Assumptions

Agent-chosen defaults, overridable.

- Events are distinguished by their `target` field.
- The hour picker offers whole hours only.
- Digest emails are sent from the existing notification sender.

## Off-limits

- The immediate notification path itself: the digest is an addition beside it.
- Weekly or monthly intervals: daily only for this work unit.

## Deferred points

None.

## Remaining risks

- A user in a timezone that shifts for daylight saving may receive two digests
  or none on the shift day.

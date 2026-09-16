# Notifications

## Decisions

- Delivery is organised by channel. Every event carries a `channel` id, and a
  channel's mute switch is the single place a user suppresses it.
- Suppression is evaluated once, at delivery time, in `deliverable()`. No
  downstream feature re-evaluates mute state on its own.

## Why

One suppression point keeps a user's mute switch meaning the same thing
everywhere it applies, instead of each surface inventing its own exception.

## Reconsider when

- A surface needs a user-visible record of what was suppressed rather than
  silent omission.

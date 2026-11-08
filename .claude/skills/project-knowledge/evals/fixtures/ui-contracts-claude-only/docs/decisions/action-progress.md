# Action progress

## Decisions

- A pending button keeps its label and width and shows a `Spinner size="sm"` in place of its icon.

## Why

Swapping the whole button for a spinner moved the layout under the user's finger.

## Still-rejected alternatives

- Replacing the button with a full-size spinner — the control jumps and the label disappears.
- Enforcing spinner size through a lint rule — runtime sizes produced false positives.

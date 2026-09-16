# Follow-up Format

Follow-ups live in `docs/follow-ups/`, one file per item. The filename is the
symptom in kebab-case, such as `metro-cache-platform-leak.md`. An item records
work a session discovered but did not resolve, so a later session can act on it
without the original conversation.

## Template

```md
# {Symptom stated as the observable problem}

**Symptom**: {What went wrong, as observed.}

**Observed evidence**: {The command, route, or output that showed it, and the
environment it came from.}

**Suspected cause**: {The mechanism believed responsible, marked as suspected
until confirmed.}

**What was tried**: {The workaround applied, what it unblocked, and what it
left unchanged.}

**Proposed next step**: {The first concrete action a later session should take.}
```

All five fields are required; an item missing any of them cannot be acted on
without the original conversation. Add nothing else — no status field, priority,
estimate, severity, or assignee.

## Lifecycle

Delete the file when the work ships or when the item is promoted into a spec
folder. Git history is the only archive.

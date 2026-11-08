# Design Entry Format

`DESIGN.md` lives at the repository root. It is where design work starts, not a
design authority: decision contracts own every rule, and this file holds values
and points at the contract that owns each visible element.

## Template

````md
# Design

Where design work starts. Decision contracts in `docs/decisions/` own every
rule; this file holds values and points at the contract that owns each element.

## Values

Source: `{token source path}`. Update this section when that source changes.

| Token | Light | Dark |
| --- | --- | --- |
| `{semantic color token}` | `{value}` | `{value}` |

Text roles: {role and size, one per role}.
Radius and spacing: {token and value}.

## Components

Source: `{shared component directory}`. Update this section when it changes.

- `{Component}`

## Rejected patterns

- {Pattern an agent would otherwise write, in a few words} → [{subject}](docs/decisions/{subject}.md)

## Map

- {Visible element, such as button loading state or toast placement} → [{subject}](docs/decisions/{subject}.md)
````

Copy theme columns only for themes the project ships. Omit `Values` or
`Components` when the project has no such source; never add an empty heading.
Map and rejected-pattern lines carry only the element or pattern and a link,
never the rule.

## Read route

Add once to `AGENTS.md`, and to `CLAUDE.md` when it exists and does not already
load `AGENTS.md`:

```md
- Work that builds or reviews screens reads `DESIGN.md` first.
```

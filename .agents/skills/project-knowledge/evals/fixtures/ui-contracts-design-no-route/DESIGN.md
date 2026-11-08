# Design

Where design work starts. Decision contracts own every rule; this file holds
values and points at the contract that owns each element.

## Values

Source: `app/global.css`. Update this section when that file changes.

| Token | Light | Dark |
| --- | --- | --- |
| `--color-background` | `#ffffff` | `#0f1115` |
| `--color-foreground` | `#111318` | `#f1f3f5` |
| `--color-muted` | `#6b7280` | `#9aa0a6` |
| `--color-accent` | `#3b5bdb` | `#748ffc` |
| `--color-danger` | `#d6336c` | `#f06595` |

Text roles: `text-title` 22/28 bold, `text-body` 16/24, `text-caption` 13/18.
Radius: `--radius-sm` 6px, `--radius-md` 12px. Spacing unit: 4px.

## Components

Source: `components/ui/`. Update this section when that directory changes.

- `Button`, `Sheet`, `Spinner`

## Rejected patterns

- Replacing a pending button with a full-size spinner → [action-progress](docs/decisions/action-progress.md)

## Map

- Text and font size → [typography](docs/decisions/typography.md)
- Button loading and disabled states → [action-progress](docs/decisions/action-progress.md)

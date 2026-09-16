# Notification settings

The settings surface of an existing SaaS dashboard, reduced to the screen a
work unit would change. Run it with `npm start` and open http://localhost:3000.

- `src/store.js` — the confirmed channels, their defaults, and the save behavior
- `src/components/Toggle.js` — the design system's toggle, used as-is
- `src/settings.js` — builds the channel rows and wires save
- `src/styles.css` — the design tokens the screen already uses

Every channel currently shows its full description; nothing collapses.

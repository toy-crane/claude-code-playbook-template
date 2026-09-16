# Notification toggle preview

An isolated component preview, not a product screen. It shows the approved
notification toggle in the states a reviewer needs to see. Run it with
`npm start` and open http://localhost:3000.

- `src/components/NotificationToggle.js` — the component under review, built
  from the approved design system pattern
- `preview/preview.js` — mounts the component in each state
- `preview/tokens.css` — the design system tokens the component consumes

Composition and interaction follow the approved pattern. Spacing and copy
inside the preview are placeholders.

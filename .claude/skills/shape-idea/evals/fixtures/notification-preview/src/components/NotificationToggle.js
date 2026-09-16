// Approved component: composition and interaction follow the design system
// switch pattern. The caller owns the label, hint, and change handler.
export function NotificationToggle({ id, name, hint, checked, disabled = false, onChange }) {
  const root = document.createElement("div");
  root.className = "notification-toggle";
  root.dataset.disabled = String(disabled);

  const text = document.createElement("p");
  text.className = "notification-toggle__text";
  const nameEl = document.createElement("span");
  nameEl.className = "notification-toggle__name";
  nameEl.textContent = name;
  const hintEl = document.createElement("small");
  hintEl.className = "notification-toggle__hint";
  hintEl.textContent = hint;
  text.append(nameEl, hintEl);

  const control = document.createElement("label");
  control.className = "switch";
  const input = document.createElement("input");
  input.type = "checkbox";
  input.id = `notification-${id}`;
  input.checked = checked;
  input.disabled = disabled;
  input.setAttribute("aria-label", name);
  input.addEventListener("change", () => onChange?.(input.checked));
  const track = document.createElement("span");
  track.className = "switch__track";
  const thumb = document.createElement("span");
  thumb.className = "switch__thumb";
  control.append(input, track, thumb);

  root.append(text, control);
  return root;
}

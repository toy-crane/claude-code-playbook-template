// Design system toggle. Used as-is by every settings screen.
export function Toggle({ id, checked, label, onChange }) {
  const wrapper = document.createElement("label");
  wrapper.className = "toggle";

  const input = document.createElement("input");
  input.type = "checkbox";
  input.id = `toggle-${id}`;
  input.checked = checked;
  input.setAttribute("aria-label", label);
  input.addEventListener("change", () => onChange(input.checked));

  const track = document.createElement("span");
  track.className = "toggle__track";
  const thumb = document.createElement("span");
  thumb.className = "toggle__thumb";

  wrapper.append(input, track, thumb);
  return wrapper;
}

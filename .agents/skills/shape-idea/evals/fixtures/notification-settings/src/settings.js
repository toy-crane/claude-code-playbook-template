import { Toggle } from "./components/Toggle.js";
import { channels, load, save } from "./store.js";

const list = document.getElementById("channels");
const status = document.getElementById("status");
const state = load();

for (const channel of channels) {
  const row = document.createElement("div");
  row.className = "channel";
  row.dataset.channel = channel.id;

  const text = document.createElement("div");
  const name = document.createElement("h2");
  name.className = "channel__name";
  name.textContent = channel.label;
  const description = document.createElement("p");
  description.className = "channel__description";
  description.textContent = channel.description;
  text.append(name, description);

  row.append(
    text,
    Toggle({
      id: channel.id,
      checked: state[channel.id],
      label: channel.label,
      onChange: (on) => {
        state[channel.id] = on;
        status.textContent = "";
      },
    }),
  );
  list.append(row);
}

document.getElementById("save").addEventListener("click", () => {
  save(state);
  status.textContent = "저장했습니다.";
});

import { NotificationToggle } from "../src/components/NotificationToggle.js";

const states = [
  { label: "켜짐 (기본값)", props: { id: "on", name: "이메일 알림", hint: "요약과 중요한 변경을 받습니다.", checked: true } },
  { label: "꺼짐", props: { id: "off", name: "푸시 알림", hint: "모바일 앱으로 즉시 받습니다.", checked: false } },
  { label: "비활성 (연결 필요)", props: { id: "disabled", name: "Slack 알림", hint: "Slack을 먼저 연결해야 합니다.", checked: false, disabled: true } },
];

const host = document.getElementById("states");

for (const state of states) {
  const card = document.createElement("div");
  card.className = "state";
  const label = document.createElement("p");
  label.className = "state__label";
  label.textContent = state.label;
  card.append(label, NotificationToggle(state.props));
  host.append(card);
}

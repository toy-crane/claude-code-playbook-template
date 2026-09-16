// Confirmed: the channels offered, their defaults, and how settings are saved.
export const channels = [
  {
    id: "email",
    label: "이메일",
    description: "요약과 중요한 변경을 이메일로 받습니다.",
  },
  {
    id: "push",
    label: "푸시",
    description: "모바일 앱으로 즉시 알림을 받습니다.",
  },
  {
    id: "slack",
    label: "Slack",
    description: "연결된 Slack 채널로 알림을 보냅니다.",
  },
];

export const defaults = { email: true, push: true, slack: false };

const KEY = "notification-settings";

export function load() {
  try {
    return { ...defaults, ...JSON.parse(localStorage.getItem(KEY) || "{}") };
  } catch {
    return { ...defaults };
  }
}

export function save(state) {
  localStorage.setItem(KEY, JSON.stringify(state));
}

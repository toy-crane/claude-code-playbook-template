export const CHANNELS = [
  { id: 'mentions', label: 'Mentions', muted: false },
  { id: 'comments', label: 'Comments', muted: true },
  { id: 'releases', label: 'Releases', muted: false },
];

export function isMuted(channelId, channels = CHANNELS) {
  const channel = channels.find((entry) => entry.id === channelId);
  return channel ? channel.muted : false;
}

export function deliverable(events, channels = CHANNELS) {
  return events.filter((event) => !isMuted(event.channel, channels));
}

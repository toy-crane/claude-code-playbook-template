import { CHANNELS } from './channels.js';

export function renderPreferences(root, channels = CHANNELS) {
  root.innerHTML = '';
  const list = document.createElement('ul');
  list.className = 'channel-list';
  for (const channel of channels) {
    const row = document.createElement('li');
    row.className = 'channel-row';
    row.innerHTML =
      '<span class="channel-name">' +
      channel.label +
      '</span><label class="switch"><input type="checkbox" data-channel="' +
      channel.id +
      '"' +
      (channel.muted ? '' : ' checked') +
      '><span>Deliver</span></label>';
    list.appendChild(row);
  }
  root.appendChild(list);
}

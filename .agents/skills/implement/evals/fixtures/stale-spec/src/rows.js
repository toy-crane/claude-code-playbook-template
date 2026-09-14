export const DELIMITER = '\t';

export function serialize(rows) {
  return rows.map((row) => row.join(DELIMITER)).join('\n');
}

export function filename(base) {
  return base + '.tsv';
}

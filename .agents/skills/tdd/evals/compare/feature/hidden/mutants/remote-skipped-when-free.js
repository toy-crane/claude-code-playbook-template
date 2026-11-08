const REMOTE_REGIONS = new Set(['jeju', 'island']);

export function shippingFee(order) {
  const { items, weightKg, region } = order ?? {};
  if (!Array.isArray(items) || items.length === 0) throw new RangeError('items');
  for (const item of items) {
    const { price, qty } = item ?? {};
    if (typeof price !== 'number' || !Number.isFinite(price) || price < 0) {
      throw new RangeError('price');
    }
    if (!Number.isInteger(qty) || qty < 1) throw new RangeError('qty');
  }
  if (typeof weightKg !== 'number' || !Number.isFinite(weightKg) || weightKg < 0) {
    throw new RangeError('weightKg');
  }
  const subtotal = items.reduce((sum, { price, qty }) => sum + price * qty, 0);
  let fee = subtotal >= 50000 ? 0 : 3000;
  if (REMOTE_REGIONS.has(region) && fee > 0) fee += 3000;
  if (weightKg > 5) fee += Math.ceil(weightKg - 5) * 1000;
  return fee;
}

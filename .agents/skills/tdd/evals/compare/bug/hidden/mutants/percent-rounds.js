export function cartTotal(items, coupon) {
  const subtotal = items.reduce((sum, { price, qty }) => sum + price * qty, 0);
  if (!coupon) return subtotal;
  if (coupon.type === 'percent') {
    return subtotal - Math.round((subtotal * coupon.value) / 100);
  }
  if (coupon.type === 'fixed') return Math.max(0, subtotal - coupon.value);
  throw new RangeError(`unknown coupon type: ${coupon.type}`);
}

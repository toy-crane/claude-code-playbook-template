export function total(lines, taxRate, coupon) {
  let subtotal = 0;
  for (const line of lines) subtotal += line.price * line.quantity;
  const discount = coupon?.type === "percent" ? subtotal * coupon.value : 0;
  const taxable = Math.max(0, subtotal - discount);
  return Math.round((taxable + taxable * taxRate) * 100) / 100;
}

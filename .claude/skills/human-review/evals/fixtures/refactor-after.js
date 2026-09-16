export function total(lines, taxRate, coupon) {
  let subtotal = 0;
  for (const line of lines) subtotal += line.price * line.quantity;
  const taxable = Math.max(0, subtotal - discountFor(subtotal, coupon));
  return roundCurrency(taxable + taxable * taxRate);
}

function discountFor(subtotal, coupon) {
  return coupon?.type === "percent" ? subtotal * coupon.value : 0;
}

function roundCurrency(amount) {
  return Math.round(amount * 100) / 100;
}

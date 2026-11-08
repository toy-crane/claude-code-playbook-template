import assert from 'node:assert/strict';
import { test } from 'node:test';
import { cartTotal } from '../src/cart.js';

test('B1: a fixed coupon larger than the subtotal leaves 0', () => {
  assert.equal(cartTotal([{ price: 3000, qty: 1 }], { type: 'fixed', value: 5000 }), 0);
});
test('B1: a fixed coupon equal to the subtotal leaves 0', () => {
  assert.equal(cartTotal([{ price: 2000, qty: 2 }], { type: 'fixed', value: 4000 }), 0);
});
test('B2: no coupon sums price times quantity', () => {
  assert.equal(cartTotal([{ price: 1200, qty: 3 }]), 3600);
});
test('B2: a percent coupon still rounds the discount down', () => {
  assert.equal(cartTotal([{ price: 1999, qty: 1 }], { type: 'percent', value: 15 }), 1700);
});
test('B2: a smaller fixed coupon is still subtracted', () => {
  assert.equal(cartTotal([{ price: 8000, qty: 1 }], { type: 'fixed', value: 2500 }), 5500);
});
test('B2: an unknown coupon type still throws RangeError', () => {
  assert.throws(() => cartTotal([{ price: 1000, qty: 1 }], { type: 'bogus', value: 1 }), RangeError);
});

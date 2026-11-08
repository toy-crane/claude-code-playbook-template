import assert from 'node:assert/strict';
import { test } from 'node:test';
import { cartTotal } from '../src/cart.js';

test('sums price times quantity without a coupon', () => {
  assert.equal(cartTotal([{ price: 1000, qty: 2 }, { price: 500, qty: 1 }]), 2500);
});

test('a percent coupon discounts the rounded-down amount', () => {
  assert.equal(cartTotal([{ price: 999, qty: 1 }], { type: 'percent', value: 10 }), 900);
});

test('a fixed coupon smaller than the subtotal is subtracted', () => {
  assert.equal(cartTotal([{ price: 5000, qty: 1 }], { type: 'fixed', value: 1000 }), 4000);
});

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { shippingFee } from '../src/shipping.js';

const order = (overrides = {}) => ({
  items: [{ price: 10000, qty: 1 }],
  weightKg: 1,
  region: 'seoul',
  ...overrides,
});

test('C1: subtotal of exactly 50,000 ships free', () => {
  assert.equal(shippingFee(order({ items: [{ price: 25000, qty: 2 }] })), 0);
});
test('C1: subtotal above 50,000 ships free', () => {
  assert.equal(shippingFee(order({ items: [{ price: 30000, qty: 1 }, { price: 40000, qty: 1 }] })), 0);
});
test('C2: subtotal below 50,000 costs 3,000', () => {
  assert.equal(shippingFee(order({ items: [{ price: 49999, qty: 1 }] })), 3000);
});
test('C2: quantity counts toward the subtotal', () => {
  assert.equal(shippingFee(order({ items: [{ price: 20000, qty: 3 }] })), 0);
});
test('C3: jeju adds 3,000 to a paid order', () => {
  assert.equal(shippingFee(order({ region: 'jeju' })), 6000);
});
test('C3: island adds 3,000 even when shipping is free', () => {
  assert.equal(shippingFee(order({ items: [{ price: 60000, qty: 1 }], region: 'island' })), 3000);
});
test('C4: exactly 5kg adds nothing', () => {
  assert.equal(shippingFee(order({ weightKg: 5 })), 3000);
});
test('C4: a partial kilogram over 5kg counts as a whole one', () => {
  assert.equal(shippingFee(order({ weightKg: 5.1 })), 4000);
});
test('C4: 7.5kg adds 3,000', () => {
  assert.equal(shippingFee(order({ weightKg: 7.5 })), 6000);
});
test('C5: empty items throw RangeError', () => {
  assert.throws(() => shippingFee(order({ items: [] })), RangeError);
});
test('C5: negative price throws RangeError', () => {
  assert.throws(() => shippingFee(order({ items: [{ price: -1, qty: 1 }] })), RangeError);
});
test('C5: non-integer quantity throws RangeError', () => {
  assert.throws(() => shippingFee(order({ items: [{ price: 1000, qty: 1.5 }] })), RangeError);
});
test('C5: zero quantity throws RangeError', () => {
  assert.throws(() => shippingFee(order({ items: [{ price: 1000, qty: 0 }] })), RangeError);
});
test('C5: negative weight throws RangeError', () => {
  assert.throws(() => shippingFee(order({ weightKg: -1 })), RangeError);
});
test('C5: non-numeric weight throws RangeError', () => {
  assert.throws(() => shippingFee(order({ weightKg: '3' })), RangeError);
});

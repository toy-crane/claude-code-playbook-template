# 버그: 정액 쿠폰으로 총액이 음수가 된다

`src/cart.js`의 `cartTotal(items, coupon)`에서 정액 쿠폰(`{ type: 'fixed', value }`)의 금액이 상품 합계보다 크면 총액이 음수로 나온다.

재현: `cartTotal([{ price: 3000, qty: 1 }], { type: 'fixed', value: 5000 })`가 `-2000`을 돌려준다.

기대 동작: 정액 쿠폰은 총액을 0원 아래로 내리지 않는다. 위 예시는 `0`이어야 한다. 그 밖의 동작(쿠폰 없음, 정률 쿠폰의 내림, 모르는 쿠폰 종류에서 `RangeError`)은 지금처럼 유지한다.

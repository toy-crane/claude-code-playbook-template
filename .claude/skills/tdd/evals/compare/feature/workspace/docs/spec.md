# 배송비 계산

`src/shipping.js`에서 `shippingFee(order)`를 내보낸다. 이 함수가 공개 인터페이스다.

`order`의 모양은 다음과 같다.

```js
{
  items: [{ price: 12000, qty: 2 }], // price는 원, qty는 개수
  weightKg: 3.2,
  region: 'seoul' // 'jeju', 'island', 그 밖의 지역 이름
}
```

반환값은 배송비(원, 정수)다.

## 수용 기준

1. 상품 합계(각 상품의 `price × qty`를 더한 값)가 50,000원 이상이면 기본 배송비는 0원이다.
2. 상품 합계가 50,000원 미만이면 기본 배송비는 3,000원이다.
3. `region`이 `'jeju'`나 `'island'`이면 3,000원이 더 붙는다. 기본 배송비가 0원이어도 붙는다.
4. `weightKg`가 5kg을 넘으면, 넘는 무게 1kg마다 1,000원이 더 붙는다. 1kg이 안 되는 나머지도 1kg으로 친다.
5. `items`가 비어 있거나, `price`가 음수이거나, `qty`가 1 이상의 정수가 아니거나, `weightKg`가 음수이거나, 이 값들이 숫자가 아니면 `RangeError`를 던진다.

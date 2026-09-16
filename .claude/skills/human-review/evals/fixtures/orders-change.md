# Order response change

Named change: `orders-v2-demo`
Environment: local contract-test fixture

## Request used for both versions

```json
{"id":"ord_demo","status":"paid","deliveryWindow":"14:00-16:00"}
```

## Previous observed response

```json
{"id":"ord_demo","status":"paid"}
```

## New observed response

```json
{"id":"ord_demo","status":"paid","deliveryWindow":"14:00-16:00"}
```

The partner stores the response exactly as received. The same change adds a
nullable internal `dispatch_note` column. A staging transcript records both the
column addition and successful rollback with representative rows unchanged.

# Studentry Flutter architecture

The UI and Riverpod state remain unchanged. Remote access is now isolated behind a Laravel REST API.

## Data flow

- `ApiClient` is the only HTTP entry point. It attaches the Sanctum bearer token and parses API errors.
- `ApiRequestQueue` limits each device to three in-flight requests and retries `429`/`5xx` responses with exponential backoff and jitter.
- Patient and appointment edits are local-first in SQLite. `SyncService` pushes up to 100 queued CRUD operations in one request, then incrementally pulls changes using `since` and a cursor.
- Store reads are paginated. The catalog is refreshed every two hours plus a random 0–15 minute stagger per device, preventing a synchronized traffic spike.
- Orders remain locally durable and are retried with the same UUID. Laravel treats that UUID as an idempotency key.
- Tokens are stored with `flutter_secure_storage`; no backend key is embedded in the app.

## API configuration

Android emulator default: `http://10.0.2.2:8000/api/v1`.

Override for a device or production build:

```bash
flutter run --dart-define=API_BASE_URL=https://api.example.com/api/v1
```

Use HTTPS in production. A physical phone must use an address reachable from the phone, not `localhost`.

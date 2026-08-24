# Production release checklist

## Blocking inputs

- Confirm ownership of the permanent application ID `io.studentry.app` before the first store record is created.
- Generate Firebase Android/iOS applications for that exact ID; never commit their configuration files.
- Configure `API_BASE_URL` as a public HTTPS URL ending in `/api/v1`.
- Generate and back up the Android upload keystore and configure Apple signing in the CI secret store.
- Replace every bracketed field in the privacy and terms templates and obtain legal approval for target countries.

## Backend

- Use the production environment template; rotate every credential and `APP_KEY`.
- Run migrations, `php artisan optimize`, and `php artisan app:verify-infrastructure` during deployment.
- Run at least one queue worker for `emails,default`, configure a scheduler, TLS, object storage, centralized logs, alerts and off-site backups.
- Test a full backup restore and the account/data deletion process.
- Run the load test against production-sized staging and retain the report.

## Mobile

- `flutter analyze` and `flutter test` must pass in CI.
- Complete academic subjects/results APIs; no user action may mutate only in-memory `dummy*` collections.
- Test login, OTP, password reset, role access, offline sync, conflicts, upload, order stock and notifications on real Android/iOS devices.
- Complete accessibility, Arabic/English, small-screen, tablet and loss-of-network testing.
- Produce signed AAB/IPA artifacts from CI only and retain symbol files for crash decoding.

## Store operations

- Provide privacy-policy and account-deletion URLs, support contact, screenshots, data-safety declarations and age rating.
- Configure crash reporting and privacy-safe analytics with consent where required.
- Use staged rollout, monitor errors/latency/queues, and keep a tested rollback procedure.

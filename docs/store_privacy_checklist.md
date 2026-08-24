# Studentry — store privacy checklist

## Public URLs to configure after deployment

- Privacy policy: `https://<production-domain>/privacy`
- External account deletion: `https://<production-domain>/account-deletion`
- Set `APP_OPERATOR_NAME` and a working `PRIVACY_CONTACT_EMAIL` in the production backend.
- Keep both pages public, HTTPS-only, and reachable without installing or opening the app.

## Google Play Data safety draft

Studentry collects the following only for app functionality, account management, security, and user-requested communications:

- Name, email address, phone number, user/account identifiers.
- University, academic year, exam number, subjects, schedules, and grades.
- Patient/health information entered by authorized clinical users.
- Photos and files explicitly selected by the user.
- Store orders, purchase details, favorites, and reviews.
- Device identifier and Firebase push token for notifications.

Current implementation notes:

- Data is not sold and there is no advertising SDK.
- Production transport must use HTTPS; release builds reject local or HTTP API endpoints.
- Local clinical data uses the encrypted, account-scoped database.
- Account deletion is available in Settings and on the public deletion page.
- Exact-alarm permissions were removed; reminders use inexact scheduling.
- Complete the Data safety form for every collected category and disclose infrastructure providers used in production.

## Apple App Privacy / review

- Declare the same categories in App Store Connect, including health data, identifiers, contact info, purchases, photos/files, and user content.
- Put the public privacy-policy URL in App Store Connect and keep the in-app policy accessible.
- Provide App Review with an active demo account for each role needed to review account-based features.
- Explain any legally required retention of shared clinical or transaction records in review notes and in the policy.

## Official references

- Google Play account deletion: https://support.google.com/googleplay/android-developer/answer/13327111
- Google Play Data safety: https://support.google.com/googleplay/android-developer/answer/10787469
- Google Play exact alarm policy: https://support.google.com/googleplay/android-developer/answer/16558241
- Apple account deletion: https://developer.apple.com/support/offering-account-deletion-in-your-app
- Apple App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/

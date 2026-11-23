# Silah Project Guide

This file is the durable handoff for anyone working on this repository. Keep it current whenever project rules, architecture, important flows, or implementation status changes.

## User's standing rules

- Do not add mock, demo, or hardcoded business data. Masjid, prayer schedule, notices, membership, finance, device, and user data must come from the backend and database.
- When a feature changes or introduces persisted data, connect the Flutter flow to a real backend API and the backend to the database. Do not stop at a UI-only implementation.
- FCM must reuse the device's existing token. Do not repeatedly create/request fresh tokens. Save the token on-device, register/relink it to the authenticated user in the backend, and update it only when Firebase itself rotates it.
- Keep this file updated so another agent can continue without relying on chat history.

## Repository layout

- `app/`: Flutter application (Riverpod, Dio, Firebase Messaging, local notifications, secure storage).
- `backend/`: NestJS REST API, Prisma ORM, PostgreSQL, Firebase Admin SDK.
- App API client: `app/lib/core/network/api_service.dart`. Its current API base URL is configured in `ApiService`.
- Backend routes use `/v1`; controllers and services are under `backend/src/modules/`.
- Database schema is `backend/prisma/schema.prisma`.

## Main Flutter flows

- Startup and session routing: `app/lib/app.dart`.
- Login and profile/masjid onboarding: `app/lib/features/auth/presentation/screens/`.
- Prayer and selected masjid state: `app/lib/features/prayer_times/data/prayer_times_provider.dart`.
- Masjid discovery and QR joining: `app/lib/features/masjid/presentation/screens/connect_masjid_screen.dart`.
- Member notices: `app/lib/features/announcements/presentation/screens/announcements_screen.dart`.
- Member home and navigation: `app/lib/features/prayer_times/presentation/screens/home_screen.dart`.
- FCM and local notification handling: `app/lib/core/services/notification_service.dart`.

## Existing backend notification data flow

- Registered devices are stored in the Prisma `Device` model (`devices` table), keyed by unique `fcmToken` and related to a user.
- Flutter registers a token through authenticated `POST /v1/auth/device-token`; implementation is in `AuthController` and `AuthService`.
- Masjid and global announcements are persisted in the `Announcement` model before push dispatch. They are read by the Flutter notices screen from the API.
- `AnnouncementsService` selects active device tokens from the database and calls `FirebaseService.sendPushNotification`.
- There is no separate notification/inbox table today. Announcement records are the persisted in-app notice source.
- FCM setup must use valid Firebase Admin credentials in the deployed backend; do not put credentials in source control or log device tokens.

## Current FCM work status (2026-11-22)

- The working tree already contained uncommitted FCM token caching changes in `notification_service.dart`; preserve those changes and finish them rather than replacing them blindly.
- Current caching uses Flutter secure storage for the device token and associated user ID, then calls the backend to register/relink.
- Flutter stores the existing FCM token in secure storage and does not call Firebase for a token again on every login. It links/relinks the stored token with `POST /v1/auth/device-token` and marks it linked only after the API succeeds; failed registration remains retryable on the next login.
- Firebase token refresh events cache the rotated token and update the backend. The token itself is never written to logs.
- Flutter local and Firebase Admin notifications now share the `silah_announcements` Android channel.
- Foreground pushes trigger database-backed notice refresh; opening a push routes members to Notices, masjid admins to their notice board for masjid notices, and super admins to broadcast notices. Admins can open broadcast records in the member notices view.
- Member Notices loads both masjid announcements and global broadcast announcements from backend APIs. Announcement records remain the persistent in-app notice source; no separate inbox table or schema migration was added.
- Firebase Admin now reads `FIREBASE_SERVICE_ACCOUNT_JSON` or Application Default Credentials. Set a real service-account secret in the deployment environment; never commit it. Invalid FCM registrations are marked inactive in the database after Firebase reports them invalid.
- `backend/.env` has no `FIREBASE_SERVICE_ACCOUNT_JSON` configured. Vercel environment variables were not inspected, so production push delivery is not confirmed until the credential is configured there.
- Validation on 2026-11-22: `npm run build` in `backend/` passed. Flutter analysis reported no compile errors; it exits with existing info-level lint notices. Tests were not run.

## Admin onboarding and prayer schedule status (2026-11-23)

- Login checks the entered number and its roles through `POST /v1/auth/check-user`; masjid admin routing uses the authenticated backend profile returned by `loginDirect`, so a mapped admin is sent to the admin dashboard.
- Admin dashboard no longer selects the first public masjid as a fallback. It resolves only masjids linked to the signed-in account.
- Masjid creation no longer inserts sample prayer times. The empty dashboard now presents “Create Your Prayer Schedule” and opens the schedule editor in the Prayer Events & Schedule tab.
- Date-range prayer editor no longer pre-fills example jamaah times. Admins must enter the masjid’s actual times before saving.
- Prisma datasource URLs now use `DATABASE_URL` and `DIRECT_URL` environment variables. Never commit database credentials into the schema or source files; keep real values in ignored environment/deployment secrets.
- Remaining requested admin work: persistent month-wide Ramadan fasting timetable, special prayer event coverage, role-aware member invites and QR onboarding review, and admin Sandha household/address/collection management. Do not represent these as complete until their Flutter, API, and database flows are connected.
- Validation on 2026-11-23: backend `npm run build` passed. Flutter analysis could not start because the installed Flutter SDK attempted to update files outside the writable project folder and was denied. Tests were not run.

## Super Admin and local prayer/Qibla status (2026-11-23)

- Super Admin now has a system overview backed by the dashboard API: active masjid/user counts, device-active users in the last 30 days, pending requests, estimated monthly Sandha due, and paid/partial collections recorded this month.
- Super Admin masjid directory reads a server-paginated endpoint that includes active, inactive, pending, and rejected masjids. Search/status filters, activate/deactivate, permanent delete, and a read-only masjid detail view are connected to backend data. The detail view includes today’s saved prayer times, members/admin count, Sandha summaries, and a map link when location data exists.
- Pending request list/approve/reject routes require the Super Admin role and only pending records can be decided. Non-Super-Admin masjid submissions remain inactive and pending until approval; approval grants the creator the masjid admin role and membership. Super Admin created masjids are approved immediately.
- User management uses the existing paginated user API and now supports viewing, deactivation/reactivation, and delete. Disabled users are rejected by login and JWT validation. The last active Super Admin cannot be deactivated.
- Removed the hardcoded master Super Admin phone/OTP path from Flutter, API auth, and session restoration. Super Admin status now comes from the database user record. `prisma/seed.ts` no longer creates demo users, masjids, prayer times, Sandha plans, or notices; it seeds roles and only provisions a real Super Admin when `BOOTSTRAP_SUPER_ADMIN_PHONE` is explicitly configured. Existing database rows are not rewritten by this seed cleanup.
- When the user has no linked masjid, local daily prayer times load from the free AlAdhan coordinate endpoint using current location. The selector keeps “Local Prayer Times” after joined masjids; local results are cached on-device by date, approximate coordinates, and Asr school choice. Jamaah times are not invented; those appear only for saved masjid schedules. Location permission is required, with a user-facing iOS permission description.
- Qibla no longer assumes a fixed Tamil Nadu coordinate/bearing. It uses current GPS or saved active-masjid coordinates. The arrow continues to rotate relative to device direction; Android’s magnetic heading is corrected to true north with the platform geomagnetic field, while iOS heading is already true-north based. No placeholder direction is shown without a usable location.
- Still outstanding from the requested roadmap: targeted broadcast audiences (including selected member/masjid and Super Admin groups), an admin-to-Super-Admin request inbox, persistent month-wide Ramadan timetable, special event schedule improvements, and admin Sandha household/address/collection management.
- Validation on 2026-11-23: Nest backend build passed. Direct Dart analysis found no compile errors; info-level lint notices remain. Tests were not run.

## User display preferences (2026-11-23)

- Member-facing prayer, sunrise, Ishraq, sunset, and fasting times display in 12-hour `h:mm AM/PM` format. Backend prayer-time values remain in their existing API/database format; admin schedule entry labels remain 24-hour because they configure backend values.
- Removed the separate language switch controls from login, onboarding, and Qibla. Language is selected from the member Profile settings and persisted locally in secure storage. Existing English/Tamil translated strings read this shared setting.
- Shared display formatter: `app/lib/core/utils/prayer_time_format.dart`; global language setting: `app/lib/core/l10n/language_provider.dart`.
- Validation on 2026-11-23: Dart analysis of the touched Flutter files found no compile errors; info-level lint notices remain. `git diff --check` passed. Tests were not run.

## Flutter API debugging (2026-11-23)

- All Silah backend requests use `ApiService`'s shared Dio client and now print copyable cURL requests, success responses, and error responses in Flutter debug builds via `ApiDebugInterceptor`.
- The same debug interceptor is attached to the separate AlAdhan local prayer-times and AlQuran clients, so current external API calls are visible too. Release builds do not print API diagnostics.
- Authorization, OTP, access/refresh/device tokens, secret/password/API-key/cookie fields, and QR token URL segments are redacted from cURL and response logs. Keep new Dio clients attached to `ApiDebugInterceptor` to preserve coverage.
- Validation on 2026-11-23: Dart analysis of touched networking files found no compile errors; info-level lint notices remain. `git diff --check` passed. Tests were not run.

## Qibla compass behavior (2026-11-23)

- Qibla dial and needle now render directly from the same live heading and bearing; avoid resetting a 0-to-heading animation on every compass event, which made the arrow appear to jump/rotate inaccurately.
- Refresh Qibla reuses the current location and reads the current compass value; it does not force location recalibration when a location is already available or ask the user to rotate the phone to calibrate.

## Member discovery and admin operations (2026-11-23)

- Public member search lists only active, approved masjids and searches name, Tamil name, city, state, and address. QR lookup and join also reject inactive or unapproved masjids.
- The QR scan flow had a busy-state re-entry bug: it marked itself processing before calling a handler that immediately returned. QR lookup now proceeds to the shared join operation without that second guard blocking it.
- Super Admin masjid and user directories now load additional backend pages on scroll; page-number controls were removed. A full-screen, read-only masjid detail view loads live dashboard metrics, saved prayer times, assigned admins, connected members, and map location.
- Masjid discovery waits for at least three characters and one second of typing idle before issuing a server search; stale search responses are ignored.
- Age was removed from onboarding, user create/register APIs, response DTOs, Prisma model, and member/admin views. The age column was dropped from `public.users` in Supabase using the requested SQL and verified absent through `information_schema` on 2026-11-23. The repeatable SQL is `backend/prisma/manual-schema-updates/2026-11-23-remove-user-age.sql`.
- A live read-only Supabase inspection found 8 masjids: 7 approved and active, 1 approved but inactive (`chennai mas`). All 8 have QR tokens. The inactive record is intentionally omitted by public discovery/join routes. `uniq` exists as an approved, active masjid in the database.
- Supabase health advisors report RLS is disabled on all 14 public application tables, which means the Data API roles can access rows without row-level policies. Do not enable RLS without designing policies for the NestJS/Postgres access model; this finding must be raised for owner review.
- Special schedule records now support edit through a masjid-scoped backend `PUT` endpoint, and the admin Prayer & Events screen exposes create/edit actions and a responsive empty state. Month-by-month daily Ramadan Sehri/Iftar schedules remain a separate required database-backed feature and are not complete yet.

## Working conventions

- Preserve unrelated user edits already present in the working tree.
- Do not run tests unless the user asks for testing or verification. Static analysis/build checks may be used when needed to validate code changes.
- Update this guide after completing a feature or changing the status above.

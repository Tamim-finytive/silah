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

## Working conventions

- Preserve unrelated user edits already present in the working tree.
- Do not run tests unless the user asks for testing or verification. Static analysis/build checks may be used when needed to validate code changes.
- Update this guide after completing a feature or changing the status above.

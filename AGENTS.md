# Silah Project Guide

This file is the durable handoff for anyone working on this repository. Keep it current whenever project rules, architecture, important flows, or implementation status changes.

## User's standing rules

- Do not add mock, demo, or hardcoded business data. Masjid, prayer schedule, notices, membership, finance, device, and user data must come from the backend and database.
- When a feature changes or introduces persisted data, connect the Flutter flow to a real backend API and the backend to the database. Do not stop at a UI-only implementation.
- FCM must reuse the device's existing token. Do not repeatedly create/request fresh tokens. Save the token on-device, register/relink it to the authenticated user in the backend, and update it only when Firebase itself rotates it.
- Do not collect a separate Tamil title in create or edit forms anywhere in the app. Forms should ask for the primary title only; existing translated titles may remain readable when returned by the backend.
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
- Masjid discovery keeps the public paginated directory separate from the user's connected masjids. Connect cards are marked `Connected` only when the authenticated `GET /v1/masjids/my/list` response includes that masjid; a successful join immediately marks only the selected masjid. Users can remain connected to multiple masjids.
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
- Connect with Masjid search now keeps the search form visible while the directory loads, shows responsive full-width result cards with separate location/connect actions, and distinguishes loading/searching/no-results states so returned database results remain visible on narrow screens.
- Public masjid discovery now uses backend pagination (`page`, capped `limit`, `hasMore`) and the Flutter screen loads batches of 20 on scroll. Search, name A–Z/Z–A ordering, and nearest-first ordering are applied by the backend; nearest search uses permissioned device coordinates and only saved masjid coordinates. Public directory responses omit QR secrets. Address/city text is searched through the existing search field. Map links with embedded coordinate patterns can be parsed by `LocationHelper`; short redirect URLs without coordinates still need GPS or explicit coordinates to provide reliable proximity.
- Validation on 2026-11-23: `npm run build` in `backend/` passed. Dart analysis of the three touched Flutter files reported no issues; Dart then logged a telemetry file permission error outside the workspace. `git diff --check` passed. Tests were not run. Deploy the backend change before releasing the Flutter client because the public `/masjids` response now returns a paginated object instead of the previous bare array.

## Admin schedule layout and session refresh (2026-11-23)

- Admin tabs now build only the selected page instead of eagerly laying out all five nested Scaffolds. Prayer rows and solar summaries wrap within narrow screens; special event actions and empty states use responsive layouts. The old five-label bottom bar was replaced with a compact Material NavigationBar.
- Access JWTs expire after 15 minutes. Flutter now refreshes with the stored refresh token after an eligible 401, shares concurrent refresh attempts, persists rotated tokens, and retries the original request once. QR/member masjid join explicitly handles 401 with one refresh-and-retry path so it works even if interceptor handling differs; when the refresh token is rejected, the session is cleared and the user is asked to sign in again. Masjid join errors now propagate to the UI instead of returning null silently.
- Foreground FCM messages publish an in-app floating notice banner with an Open action to the persisted Notices screen, and still attempt the local notification. Notification permission setup runs after login even if an existing FCM token is reused; token generation remains only for the no-cached-token case. Foreground local-notification errors are caught and logged in debug mode.
- Validation after notification UI changes: targeted Dart analysis of `app.dart` and `notification_service.dart` reported no issues; `git diff --check` passed. The analyzer again prints its outside-workspace telemetry permission warning after reporting no issues. Tests were not run.
- Validation on 2026-11-23: targeted Dart analysis reported no errors (only existing info-level lints); `git diff --check` passed. The Dart process prints a telemetry file permission warning after analysis because it cannot update a file outside the workspace. Tests were not run.
- Age was removed from onboarding, user create/register APIs, response DTOs, Prisma model, and member/admin views. The age column was dropped from `public.users` in Supabase using the requested SQL and verified absent through `information_schema` on 2026-11-23. The repeatable SQL is `backend/prisma/manual-schema-updates/2026-11-23-remove-user-age.sql`.
- A live read-only Supabase inspection found 8 masjids: 7 approved and active, 1 approved but inactive (`chennai mas`). All 8 have QR tokens. The inactive record is intentionally omitted by public discovery/join routes. `uniq` exists as an approved, active masjid in the database.
- Supabase health advisors report RLS is disabled on all 14 public application tables, which means the Data API roles can access rows without row-level policies. Do not enable RLS without designing policies for the NestJS/Postgres access model; this finding must be raised for owner review.
- Special schedule records now support edit through a masjid-scoped backend `PUT` endpoint, and the admin Prayer & Events screen exposes create/edit actions and a responsive empty state. Month-by-month daily Ramadan Sehri/Iftar schedules remain a separate required database-backed feature and are not complete yet.
- In Admin "Manage Prayer & Events" (Tab 2), when no prayer times exist in the database, only the primary "Create Prayer Schedule" and "Set Date Range Schedule" buttons are displayed (no edit buttons on empty state). Once prayer times are created, the screen switches to displaying the configured timings with the "Edit Schedule" and "Edit Date Range Schedule" actions.
- In "Connect with Masjid" directory (`connect_masjid_screen.dart`), clicking Connect now only sets the loading state (`Connecting…` spinner) on the specifically clicked masjid card via `_connectingMasjidId`, preventing other unselected masjid cards from showing loading spinners simultaneously.
- Android background push notifications are configured in `AndroidManifest.xml` with `com.google.firebase.messaging.default_notification_channel_id` mapped to `silah_announcements`, launcher icon metadata, and `VIBRATE`, `WAKE_LOCK`, and `RECEIVE_BOOT_COMPLETED` permissions so incoming push notifications trigger the heads-up notification channel even when the app is in background or killed.
- The Flutter FCM background callback initializes Firebase and handles data-only pushes by showing a local notification on the shared `silah_announcements` channel. For normal notification-plus-data pushes, Android/iOS displays the remote notification itself; the callback intentionally does not create a duplicate. Admin masjid notices default to push delivery unless explicitly disabled, target active registered devices of connected masjid members, and backend logs delivery counts without logging tokens.
- A device receives push only after its active FCM token is registered for a user who belongs to the notice audience and notification permission is allowed. A previous read-only Supabase check found only 3 active Android device registrations across 16 user accounts at that time; account rows without registered app devices cannot receive FCM.
- Follow-up read-only check on 2026-11-23 confirmed 3 active Android registrations still exist. The masjid notice audience can have fewer registered devices than member accounts. This workspace has no `FIREBASE_SERVICE_ACCOUNT_JSON` in `backend/.env`; deployed Vercel variables are not accessible through available tools, so verify Firebase Admin credentials and the `FirebaseService` delivery logs before claiming remote delivery is working.
- Android notification permission status is now printed in Flutter debug logs after the permission request. Remote and local notification icons use `@drawable/ic_stat_silah`, a monochrome status icon.
- Validation for this update: `git diff --check` passed. Backend build is currently blocked by existing Prisma client/schema mismatch errors for `announcementUserState`/`userStates` in `announcements.service.ts` (lines 68, 148, 155, 189, 199); none point to the push-dispatch changes. Flutter analysis could not start because the installed Flutter SDK attempted to write its engine cache outside the workspace and the environment denied it. Tests were not run.

## Flutter UI refinement (2026-11-23)

- Shared UI tokens remain the source of truth in `app/lib/core/constants/app_colors.dart`, `app_spacing.dart`, and `app/lib/core/theme/app_theme.dart`. Preserve the emerald primary, warm gold accent, light neutral surfaces, readable body text, and clear status colors; do not add a second theme or UI package.
- The shared theme now standardizes text roles, input borders, 48 px button targets, low-elevation bordered cards, dialogs, snackbars, and Material 3 navigation. Home and admin surfaces use the theme background instead of separate near-identical hardcoded backgrounds.
- Member Home uses Material `NavigationBar`, a responsive content width, a live Gregorian date, and no static “Live Sync” or fixed Hijri date claim. Prayer time rendering continues to use the shared 12-hour formatter.
- Login, onboarding, Qibla, member notice/Sandha, and Super Admin detail content are constrained on wide viewports. Home navigation, Quran title/search, and notice/Sandha headers and empty states use the saved global English/Tamil preference; notice titles/bodies use localized backend fields when available, and notice timestamps use 12-hour time.
- Super Admin navigation now uses the same Material 3 navigation component as the member/admin app. Keep directory, notice, prayer, member, and finance content sourced from backend APIs; never add fixture records to production flows.
- This pass received source review and Flutter static analysis with no compile errors; existing info-level lints remain. Screens were not captured in a representative in-app fixture, so do not claim rendered visual verification until checked on a safe emulator/app-only screen in compact and wide layouts.
- Updated the shared app palette to the supplied Qibla reference: forest green, warm ivory surfaces, and restrained gold. Replaced repeated primary green/background literals in member Home, masjid/admin, onboarding, and shared app surfaces with the shared palette. The Home layout keeps its live prayer, masjid, and notice data while matching the reference's spacious rounded-card hierarchy.
- Reworked the Qibla view with a responsive compass dial, gold tick marks, bearing/distance summary, turn guidance, location/sensor states, and the existing true-north compass calculations. Empty location/heading states do not display fabricated bearing or alignment values. The Dribbble clip informed card hierarchy and content spacing; the supplied Qibla image sets Silah’s forest/ivory/gold palette.
- Targeted Dart analysis of the touched palette and UI files reported no errors or warnings; info-level lints remain. Dart formatting completed for the palette and Qibla screen. The Dart process emitted an existing telemetry file permission warning outside the workspace. Tests and rendered device preview were not run.

## Member notices and form layout (2026-11-23)

- Member Notices uses authenticated `GET /v1/announcements/my` with a status filter and cursor pagination. It requests 20 notices initially and 20 more near the end of the list; the backend returns `items`, `nextCursor`, and `hasMore` with stable newest-first ordering. Keep unread as the default tab and request the `UNREAD` filter first.
- The Read tab requests only read notices. Per-user mark-read/mark-unread and hide actions use the existing persisted announcement-user-state endpoints, so hiding a notice affects only that user. Masjid and broadcast notices are combined from this user-scoped backend query, which excludes notices outside their memberships and audience.
- The admin New Notice entry is a full-screen form with only Heading and Message. Saving still creates a database-backed masjid announcement and requests push dispatch; it sends no Tamil title/body fields. New create forms should use keyboard-safe scrolling, a bottom action area above the keyboard, and visible spacing between fields.
- Added visible vertical gaps to admin/super-admin creation dialogs and increased shared input padding. Existing short forms remain scrollable dialogs; retain `SingleChildScrollView` around longer dialog forms and use a full-screen route for forms that need an always-visible bottom action.
- Validation on 2026-11-23: targeted Dart analysis of touched files reported no errors or warnings; info-level lints remain. `git diff --check` passed. Nest backend build passed after regenerating the local Prisma client from the existing schema; no database migration or data change was made. Tests and rendered device preview were not run. Dart formatting emitted the known telemetry file permission warning outside the workspace after formatting completed.

## Working conventions

- Preserve unrelated user edits already present in the working tree.
- Do not run tests unless the user asks for testing or verification. Static analysis/build checks may be used when needed to validate code changes.
- Update this guide after completing a feature or changing the status above.

## Responsive overflow fixes (2026-11-24)

- The Home Asr calculation dialog keeps its option labels inside the dialog width; the prayer header stacks the method selector on narrow content widths and truncates long dates/method labels safely.
- The My Masjids bottom-sheet title shares available width with its close button and wraps to two lines. Active masjid city labels are constrained, and the active/local status row can wrap.
- Masjid search result actions and Sandha summary heading/status use wrapping layouts on narrow screens rather than fixed single-line rows.
- Onboarding section headings now share available width with their icons, allowing long labels to wrap on compact windows.
- Check new `Row` children that contain user/backend text: use `Expanded`/`Flexible`, max lines with ellipsis, or `Wrap` where actions need to move onto a second line. Preserve system text scaling; do not fix overflow by clipping the whole screen or reducing accessibility text size.
- `git diff --check` passed. Full app Dart analysis completed with no compile errors; existing info-level lints remain. The analyzer emitted its existing telemetry file permission warning outside the project. No tests or device preview were run.

## App Icon, Media Notices & Auto-Refresh Status (2026-11-24)

- App Icons & Assets: User's updated `app/asset/logo.png` (1254x1254) has been processed and deployed across Android launcher mipmaps (mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi), Android notification status bar icon (`ic_stat_silah.png`), iOS AppIcon catalog (`AppIcon.appiconset` 20x20 through 1024x1024), Web favicon & PWA icons (192, 512, maskable), and `app/asset/logo.jpg`.
- Rich Notice Creation (`NoticeEditorScreen`): Admin can provide Heading and Description, attach an image from camera or gallery (`image_picker`), and record a voice message with a live timer and playback preview (`record: ^7.2.0`, `just_audio`). Media is uploaded directly via `POST /v1/uploads` into public Supabase Storage bucket `silah-media`, and `imageUrl`, `audioUrl`, and `audioDuration` are saved to the PostgreSQL `announcements` table via `announcements.service.ts`.
- Member Notices & Playback (`announcements_screen.dart`): Fixed contrast on tabs (white label on forest green header). Each notice card renders image thumbnails with full-screen preview on tap, and in-card audio player with seek slider, duration formatting, and an Auto-play toggle switch. Marking as read immediately updates UI, and switching back to the Notices tab in `home_screen.dart` refreshes the list to keep read/unread tabs synchronized.
- Validation: Backend build passed (`nest build` 0 errors). Dart formatting and `git diff --check` passed.
- Fixed Android Gradle build task dependency: replaced eager `tasks.named("assembleRelease")` with lazy `tasks.matching { it.name == "assembleRelease" }.configureEach` in `app/android/app/build.gradle.kts` so `flutter run --debug` does not fail looking for release tasks.
- Resolved Android duplicate resource collision by removing redundant `res/drawable/ic_stat_silah.png`, retaining the vector `ic_stat_silah.xml` for status bar notifications.

## App name and APK output (2026-11-24)

- The Android launcher label, iOS display name, and web app title are `Silah`. Keep the Dart package name and Android application ID `com.finytive.silah` unchanged so imports, Firebase setup, and installed app identity remain stable.
- `:app:assembleRelease` keeps Flutter's standard artifact and copies the release APK to `app/build/app/outputs/flutter-apk/Silah.apk` for sharing.

## Adhan alarms, Quran menu, and notice form follow-up (2026-11-24)

- The Home Alert control now enables or disables five daily device-side Adhan reminders using the currently selected live prayer-time map (masjid schedule or local prayer API). Stable notification IDs replace prior alarms, the enabled choice is saved on-device, and changed prayer times reschedule the alarms. Android exact-alarm permission, reboot rescheduling receivers, local timezone lookup, and the user's `app/asset/azan1.mp3` Android notification sound are configured. This uses the existing prayer data; no example schedule was added.
- The Home three-dot menu opens the existing Quran reader, which fetches live surah/ayah data from AlQuran Cloud through the debug-logged Dio client.
- Special schedule create/edit now asks for the primary event title only and omits `titleTa` from its write payload. Do not remove legacy translated columns or backend read support unless separately requested.
- The New Notice screen must visibly collect a heading and message, with the message required, before optional image/voice attachments. The existing `POST /v1/uploads` and Supabase Storage flow saves attachment URLs to the database-backed announcement; the member notice card previews images and provides a user-controlled auto-play toggle for voice messages. Existing Prisma columns `imageUrl`, `audioUrl`, and `audioDuration` are already in place, so this work adds no schema migration.
- Validation on 2026-11-24: targeted Dart analysis reported no compile errors; existing info-level lint notices remain. `git diff --check` passed. The Dart tool also printed its existing telemetry-file permission warning outside the workspace. Tests and Android device alarm playback were not run.

## Self-service masjid approval handoff (2026-11-24)

- Self-service masjid registration creates an inactive `PENDING` record. It must remain unavailable in public discovery and the requester must remain a normal member until a Super Admin approves it. The Super Admin request screen already provides explicit Approve and Reject actions.
- Approval assigns the requester the masjid ADMIN role and primary membership, then attempts an FCM push to that user's active registered devices (`MASJID_ADMIN_APPROVED`, with the masjid ID). Push is best-effort; database approval stands if FCM delivery fails. Check the logged recipient/delivery counts and deployed Firebase Admin credentials when diagnosing missing pushes.
- After an applicant submits a pending request, the app now tells them it is awaiting review and routes them to normal Home. Opening the approval push refreshes `/auth/me` and routes directly to that masjid's Admin dashboard. A fresh login or app restart also refreshes the profile and routes approved admins from the backend role. Profile settings in the member app and the Admin settings tab expose the existing switch back to the User app.
- Validation on 2026-11-24: `npm run build` in `backend/` passed. Targeted Dart analysis of `app.dart`, `onboarding_screen.dart`, and `home_screen.dart` reported no compile errors; existing info-level lint notices remain. `git diff --check` passed. Tests were not run. Production push delivery still depends on Firebase Admin credentials and the requester having an active registered FCM device.

## Multipart media upload debug fix (2026-11-24)

- Dio `FormData` must bypass JSON encoding in `ApiDebugInterceptor`; multipart logs now render form fields and a filename placeholder without serializing file bytes or printing the device-local path. Do not set an explicit bare `Content-Type` header for multipart cURL output; let curl/Dio add the boundary.
- `ApiService.uploadFile` sets `Options(contentType: Headers.multipartFormDataContentType)` and lets Dio generate the multipart boundary. Backend `POST /v1/uploads` already accepts the `file` multipart field and stores it in Supabase Storage; the reported failure occurred in Flutter request logging before reaching the backend.
- Validation on 2026-11-24: targeted Dart analysis of networking, onboarding, and Home files reported no compile errors; `git diff --check` passed. Tests and a device upload were not run.

## Centralized Frontend Error Handling (2026-11-24)

- Introduced `ApiException` and `ApiService.getErrorMessage(e)` in `app/lib/core/network/api_service.dart`.
- The helper automatically unwraps backend error structures (`error.message`, `message` array or string), network timeouts, status codes (401, 403, 404, 500), and custom exception messages.
- Replaced raw Dio exception logging and `Failed: $e` string interpolations across `onboarding_screen.dart`, `otp_login_screen.dart`, `connect_masjid_screen.dart`, `admin_dashboard_screen.dart`, and `super_admin_dashboard_screen.dart` with `ApiService.getErrorMessage(e)`.
- Backend validation and duplicate messages (e.g., `Duplicate Masjid Detected: "..." is already registered within ~100 meters...`) now render cleanly in frontend error banners and SnackBars without technical DioException prefixes.

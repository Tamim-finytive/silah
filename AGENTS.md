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
- Remaining requested admin work: role-aware member invites and QR onboarding review, and admin Sandha household/address/collection management. Do not represent these as complete until their Flutter, API, and database flows are connected.
- Validation on 2026-11-23: backend `npm run build` passed. Flutter analysis could not start because the installed Flutter SDK attempted to update files outside the writable project folder and was denied. Tests were not run.

## Super Admin and local prayer/Qibla status (2026-11-23)

- Super Admin now has a system overview backed by the dashboard API: active masjid/user counts, device-active users in the last 30 days, pending requests, estimated monthly Sandha due, and paid/partial collections recorded this month.
- Super Admin masjid directory reads a server-paginated endpoint that includes active, inactive, pending, and rejected masjids. Search/status filters, activate/deactivate, permanent delete, and a read-only masjid detail view are connected to backend data. The detail view includes today’s saved prayer times, members/admin count, Sandha summaries, and a map link when location data exists.
- Pending request list/approve/reject routes require the Super Admin role and only pending records can be decided. Non-Super-Admin masjid submissions remain inactive and pending until approval; approval grants the creator the masjid admin role and membership. Super Admin created masjids are approved immediately.
- User management uses the existing paginated user API and now supports viewing, deactivation/reactivation, and delete. Disabled users are rejected by login and JWT validation. The last active Super Admin cannot be deactivated.
- Removed the hardcoded master Super Admin phone/OTP path from Flutter, API auth, and session restoration. Super Admin status now comes from the database user record. `prisma/seed.ts` no longer creates demo users, masjids, prayer times, Sandha plans, or notices; it seeds roles and only provisions a real Super Admin when `BOOTSTRAP_SUPER_ADMIN_PHONE` is explicitly configured. Existing database rows are not rewritten by this seed cleanup.
- When the user has no linked masjid, local daily prayer times load from the free AlAdhan coordinate endpoint using current location. The selector keeps “Local Prayer Times” after joined masjids; local results are cached on-device by date, approximate coordinates, and Asr school choice. Jamaah times are not invented; those appear only for saved masjid schedules. Location permission is required, with a user-facing iOS permission description.
- Qibla no longer assumes a fixed Tamil Nadu coordinate/bearing. It uses current GPS or saved active-masjid coordinates. The arrow continues to rotate relative to device direction; Android’s magnetic heading is corrected to true north with the platform geomagnetic field, while iOS heading is already true-north based. No placeholder direction is shown without a usable location.
- Still outstanding from the requested roadmap: targeted broadcast audiences (including selected member/masjid and Super Admin groups), an admin-to-Super-Admin request inbox, special event schedule improvements, and admin Sandha household/address/collection management.
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
- Supabase health review on 2026-11-24 found 13 public application tables with RLS disabled and `announcement_user_states` with RLS enabled but no policies. The Supabase Data API exposure is a critical security risk. Do not enable RLS broadly without designing policies for the NestJS/Postgres access model; `announcement_user_states` also needs a policy plan. Raise this for owner review.
- Special schedule records now support edit through a masjid-scoped backend `PUT` endpoint, and the admin Prayer & Events screen exposes create/edit actions and a responsive empty state.
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

## Sandha UPI payment and receipt review (2026-11-24)

- Admins manage the monthly Sandha plan and payment destination from Members → Sandha Management. Plans store their monthly amount, UPI ID, payee name, and optional admin contact phone in `sandha_plans`; phone is contact information and is not treated as a UPI address.
- Member Sandha uses a `upi://pay` link with the saved VPA, payee, remaining monthly amount, INR currency, and month note. Android manifest declares the `upi` query scheme. Returning from the UPI app is not proof of payment; members separately upload a screenshot.
- Receipt screenshots are validated as JPG/PNG/WEBP (8 MB max), stored in the private Supabase Storage bucket `silah-private`, and referenced by object path in `sandha_payments.proof_path`. The API returns one-hour signed viewing URLs only in authenticated, masjid-scoped member/admin reads. Do not move these files into public `silah-media`.
- Submitted screenshots create `PENDING` payment rows. Admin/Finance roles can view month-filtered history, inspect the private receipt, and approve to `PAID` or reject to `REJECTED`; the reviewer and verification time are persisted. Admin history is paginated at 20 items and loads more on scroll with expected, collected, outstanding, and pending-proof summaries.
- Live database migration is `backend/prisma/manual-schema-updates/2026-11-24-sandha-upi-payment-proofs.sql`. Applied to Supabase project `eojasudtbpgwwtivcvbs` on 2026-11-24; verified plan/payment columns, `REJECTED`, and private bucket (`public=false`). No demo payment rows were inserted. UPI app intent does not independently confirm bank settlement; screenshots require admin review unless a payment gateway is added later.
- Backend `npm run build` passed. Targeted Dart analysis reported no compile errors (only info-level lints); the local Flutter launcher could not update its SDK cache outside the writable project, so analysis ran through the bundled Dart SDK. `git diff --check` remains to be run after the final edits. Tests and device preview were not run.

## Masjid-specific prayer schedule integrity (2026-11-24)

- The prayer-times `/today` endpoint returns only the row for the requested calendar date. It must never fall back to the latest date in that masjid, because that makes an old schedule look newly configured for today.
- Flutter sends the device's local calendar date to `/today`, avoiding a server UTC date mismatch for users in other time zones.
- Admin login passes the masjid ID/name from the authenticated `adminRoles` record into `AdminDashboardScreen`. The admin dashboard no longer falls back to the first ordinary membership; only an assigned admin masjid can be managed.
- Cached member prayer rows are no longer hydrated or displayed; the previous local prayer-row cache is deleted on startup. The selected masjid ID may persist, but its date-specific schedule is fetched from the backend before display. Switching masjids clears the previous times and countdown immediately.
- The Prayer & Events tab keeps the create-schedule and date-range actions visible when that masjid has no saved schedule. Once the backend returns saved timings, it exposes edit actions. Never add placeholder prayer values to make the screen look populated.
- The Prayer & Events empty-state card and its heading are live widgets; keep the card wrapper intact so the action buttons and explanatory text render.
- Prayer-time lookup errors must remain distinct from a successful response with `data: null`: show a retry/error state for request failures and show the create-schedule action only after a successful empty response.
- Validation on 2026-11-24: backend `nest build` passed. Targeted Dart analysis found no compile errors (only existing info-level lints); the installed SDK emitted its usual analytics file permission warning after analysis. `git diff --check` passed after whitespace cleanup. Tests and device preview were not run.
- Removed confirmed legacy seed fixtures from Supabase project `silah-db`: the old repository seed script created `Jamia Masjid` and `Madina Masjid`, their placeholder prayer row, demo admin/member accounts, and linked sample announcement/Sandha data. Deleted only those verified fixture records and their dependencies. Post-delete query confirmed 0 matching masjids, prayer rows, and demo accounts; 9 masjids and 6 prayer rows remain. Other rows are not identified by the historical seed and were preserved.
- Startup no longer hydrates cached masjid prayer rows; it revalidates the selected masjid and fetches that local calendar day's database row before displaying timings. Changing masjids clears times/countdown immediately, and API failures clear stale values. Admin dashboard and Prayer & Events now show retryable load errors rather than a blank screen or a false “no schedule” state.

## Prayer & Events month calendar and fasting schedules (2026-11-24)

- Prayer & Events now loads the selected masjid's full saved month from `GET /v1/masjids/:id/prayer-times/schedule`, and marks saved days in a date calendar. Selecting a date shows that date's persisted prayer rows and create/edit controls. Home's current-day row and the management screen use the same masjid and `prayer_times` data; the screen must never fill absent dates with generated sample timings.
- Single-day create/edit and the existing range form persist through the prayer-times API. Range writes are limited to 31 days and upsert transactionally; all five Jamaah times are required. The range screen supports each date's shared Adhan/Jamaah values and optional sunrise/sunset/Jummah.
- Added `ramadan_day_schedules` for one saved Sehri end and Iftar time per masjid/date, plus optional notes. `GET /v1/masjids/:id/prayer-times/ramadan?year=&month=` reads a month; the ADMIN-guarded `PUT .../ramadan` upserts 1–31 selected days. Flutter shows fasting markers and create/edit controls alongside prayer dates. The SQL is tracked at `backend/prisma/manual-schema-updates/2026-11-24-add-ramadan-day-schedules.sql`; the live table was created empty and contains no mock rows.
- Special prayer schedules remain in the existing `special_schedules` table and are shown in the same screen; the calendar marks their date ranges. Ramadan fasting is stored separately from special prayer events. Taraweeh or other special prayers can use a single date or a date range.
- Database check for the signed-in admin's `sunnath` masjid confirmed a persisted `2026-11-24` prayer row, with the five Jamaah values stored as `12:00`. Do not replace these real user-entered values; selecting that day must display the saved row. The fasting schedule table currently has zero rows, so its empty state is correct until an admin saves real times.
- Validation: NestJS build passed. Targeted Dart analysis reported no compile errors; remaining diagnostics are existing/info-level lints plus analyzer warnings in the existing prayer card section. `git diff --check` passed. Tests and rendered device preview were not run. The Dart process emits a permission warning when it tries to update telemetry outside the workspace.
- Security follow-up: Supabase reports RLS enabled on `ramadan_day_schedules` with zero policies. The NestJS backend uses its database connection, but any direct Supabase Data API access would be denied; review and define least-privilege policies before exposing this table through Supabase client access. Existing public tables also have broader RLS advisories; do not enable blanket policies without reviewing the NestJS access model.

## Prayer & Events two-tab calendar workflow (2026-11-24)

- Admin Manage Prayer & Events now has two inner tabs: `Prayers` and `Events`. Both show the month calendar and use month arrows for history; no date dropdown is used.
- Date-range entry starts from a `Select date range` action. Tap a start date and then an end date directly on the visible calendar; the form opens with that range. Changing months while choosing a range is supported. Tap the same date twice for a one-day range. Prayer and Ramadan ranges are capped at 31 days; special prayer/event ranges at 366 days.
- The Prayers tab shows persisted daily timings for the selected date or a create empty state. Existing rows are colored by their saved timing set; selecting a day shows the real row and edit action. Bulk create/edit still writes each date through the existing prayer-times backend range upsert and `prayer_times` rows.
- The Events tab shows Ramadan fasting times for the selected date, and only special events active on that selected date. Ramadan date ranges save one row per day (`sehriEnd`, `iftarTime`, optional notes) through `PUT /v1/masjids/:id/prayer-times/ramadan`; event dates and times continue through existing masjid-scoped special-schedule create/update/delete APIs and `special_schedules`. Month navigation provides history without rendering the full history as a long list.
- Each selected date range is rendered directly in calendar cells with distinct color groups; Ramadan and special event markers remain distinguishable if their dates overlap. Eid can be created as a single-day special prayer; Taraweeh and other events may cover ranges.
- This UI pass reused the existing API/schema work above; it added no fixture data or new database schema. Validation: targeted Dart analysis reported no compile errors (existing info-level lints only); `git diff --check` passed. Backend code was unchanged in this UI pass; its build had passed in the preceding prayer schedule work. No tests or device preview were run. Dart may still emit the telemetry file permission warning outside the workspace.

## Super Admin Masjid Directory filters (2026-11-24)

- Masjid Directory continues to request 20 rows per page and append the next backend page as the list scrolls. Search, activity state, approval state, creation-date range, and sort options are server-side query parameters; stale in-flight page results are discarded after a filter change.
- Filters include activity (`All activity`, `Active`, `Stopped`), approval (`Any approval`, `Approved`, `Pending`, `Rejected`), newest/oldest creation date, name A–Z/Z–A, and a creation date range. The API endpoint is `GET /v1/masjids/admin/directory`; backend filtering happens before count and pagination.
- Removed pause/play activation controls from Masjid Directory. Approval state uses compact approved/pending/rejected icons with tap/tooltip descriptions. Active/stopped remains a small status dot with a tooltip, and the masjid name may wrap to two lines for readability. Keep database data and detail navigation intact.
- Masjid create form asks only for the primary name; legacy `nameTa` is still displayed when returned but not requested on create.
- Validation on 2026-11-24: NestJS build passed; targeted Dart analysis reported no compile errors (info lints only); `git diff --check` passed. Tests and rendered device preview were not run. Dart reports the existing telemetry file permission warning outside the workspace.
- Post-cleanup Supabase review: 13 public tables still have RLS disabled, and `announcement_user_states` has RLS enabled without policies. Do not change this without an authorization policy design for the NestJS database access path.

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

## Super Admin approval-request layout (2026-11-24)

- The Super Admin dashboard now builds only its selected tab; do not place all nested tab Scaffolds in an `IndexedStack` when each tab owns scrollable lists. This prevents offstage list children from receiving invalid layout constraints and reduces unnecessary work.
- Pending masjid request cards wrap applicant details and approve/reject actions on compact widths. The request screen filters server-side by Waiting for approval, Approved, Rejected, or All, and loads pages as the admin scrolls. Keep long address/applicant text bounded and wrapping so scrolling the approval list cannot leave an unlaid-out sliver child.
- The pasted device trace showed HTTP 200 for both `/masjids/admin/directory` (11 records, mixed statuses) and `/masjids/requests/pending`; those responses identify a Flutter layout failure rather than an API failure. `listAdminDirectory` supports the approval-status filters and returns the creator's name/phone for each request card.
- Validation on 2026-11-24: `npm run build` in `backend/` passed. Targeted Dart analysis of `super_admin_dashboard_screen.dart` reported no compile errors; `git diff --check` passed. No device screenshot or tests were run.

## Centralized Frontend Error Handling (2026-11-24)

- Introduced `ApiException` and `ApiService.getErrorMessage(e)` in `app/lib/core/network/api_service.dart`.
- The helper automatically unwraps backend error structures (`error.message`, `message` array or string), network timeouts, status codes (401, 403, 404, 500), and custom exception messages.
- Replaced raw Dio exception logging and `Failed: $e` string interpolations across `onboarding_screen.dart`, `otp_login_screen.dart`, `connect_masjid_screen.dart`, `admin_dashboard_screen.dart`, and `super_admin_dashboard_screen.dart` with `ApiService.getErrorMessage(e)`.
- Backend validation and duplicate messages (e.g., `Duplicate Masjid Detected: "..." is already registered within ~100 meters...`) now render cleanly in frontend error banners and SnackBars without technical DioException prefixes.

## Background Notification Voice Reading (TTS) (2026-11-24)

- Implemented native `TtsManager` (`app/android/app/src/main/kotlin/com/finytive/silah/TtsManager.kt`) utilizing Android's native `TextToSpeech` engine. Detects Tamil Unicode ranges (`0x0B80..0x0BFF`) to speak in `ta-IN` or defaults to the device's locale / English.
- Created `SilahFirebaseMessagingService` extending `FlutterFirebaseMessagingService` with priority 1000 in `AndroidManifest.xml` so background and incoming push notifications invoke `TtsManager.speak(...)` immediately on reception.
- Added `silah/tts` MethodChannel to `MainActivity.kt` and wired `NotificationService.speakHeading` in `app/lib/core/services/notification_service.dart` across `firebaseMessagingBackgroundHandler` and `FirebaseMessaging.onMessage`.
- Updated `backend/src/common/firebase/firebase.service.ts` to ensure `title` and `body` are always mirrored in the `data` payload so the notification heading is accessible in all Android delivery states.
- Added `com.google.firebase:firebase-messaging:24.1.0` directly to `app/android/app/build.gradle.kts` dependencies and set `compileSdk = flutter.compileSdkVersion` so `SilahFirebaseMessagingService` compiles with full access to Android Firebase types.
- Fixed syntax error in `home_screen.dart`: cleaned up commented code, stray closing brace, and missing reference in `_buildPrayerTimingsHeader()`.
- Fixed `_buildTopAppBar()` in `home_screen.dart`: restored drawer menu `IconButton` on `leading` and moved Holy Quran `PopupMenuButton<String>` to `actions`.
- Removed 3-dots `PopupMenuButton` completely from `_buildTopAppBar()` as requested; Holy Quran is accessible exclusively from the top-left Menu icon via Side Nav (Drawer).
- Fixed drawer opening from nested Scaffold: configured `_scaffoldKey` and passed `drawer: _buildDrawer()` to the inner home Scaffolds so the 3-line menu icon reliably opens the Side Nav containing Holy Quran.
- Redesigned "Connect with Masjid" directory layout: eliminated bloated dead space by making the top search header compact (~115px instead of ~250px), reducing search field and sort row padding, and redesigning masjid cards to ~88px height (compact 38x38 icon, single-line text with inline distance badge, and right-aligned 32px action buttons). 4+ masjids now fit on screen comfortably.
- Modern Profile Screen Design for All 3 Roles: created interactive UI artifact `profile_screens_3_roles.html` demonstrating clean, modern profiles for Member, Masjid Admin, and Super Admin with role switching and bilingual (English/Tamil) support.
- Redesigned "Masjid Approval Requests" (Super Admin Tab 2): made the top status filter dropdown compact, removed bloated dividers and gaps, and redesigned request cards to ~125px height (compact 36x36 mosque icon, single-line location/applicant rows, and side-by-side 32px Reject/Approve action buttons aligned to the right without wrapping). 3 to 4 requests now fit comfortably on screen.

## Fullscreen Masjid Invite QR with PDF Export, Print & WhatsApp Sharing (2026-11-24)

- Created dedicated full-screen screen `MasjidInviteQrScreen` (`app/lib/features/admin/presentation/screens/masjid_qr_screen.dart`).
- Fullscreen QR: Tapping the QR card, the top bar QR button, or "Fullscreen QR & Options" in Admin Dashboard now opens a dedicated, high-resolution full-screen view with the Masjid Name, Tamil name, city/address, large crisp QR code, and token with copy action.
- Print Option: Integrated `printing` and `pdf` packages. Clicking **Print** invokes `Printing.layoutPdf` to open the native device Print Dialog (AirPrint / Android Print Service) with page preview and printer selection.
- Export as PDF: Formats an A4 document with the Silah banner, Masjid title, location, high-resolution vector QR code, join token, and member onboarding instructions, allowing immediate saving or document sharing via `Printing.sharePdf`.
- WhatsApp Share: Generates a pre-composed WhatsApp invite message with the Masjid title, token, and Silah download link, launching `whatsapp://send` directly or falling back to Web WhatsApp / system share sheet.
- Added `pdf: ^3.13.1`, `printing: ^5.15.1`, and `share_plus: ^12.0.2` to `app/pubspec.yaml`. Both Dart analysis and `git diff --check` passed cleanly.

## Qibla Screen Box Heights & App-Wide Portrait Mode Enforcement (2026-11-24)

- Reduced Qibla Box Heights:
  - `_QiblaSummaryCard` (white card): reduced padding to `14x10`, mosque container to `44x44`, bearing text from 34px to 26px, and bottom gap to 8px. Height reduced from ~155px to ~95px (~38% reduction).
  - `_QiblaTurnCard` (green card): reduced padding to `14x10`, turn icon container to `32x32`, tightened alignment bar and helper text. Height reduced from ~150px to ~100px (~33% reduction).
  - Reduced gap between summary and turn cards from 14px to 8px, giving more vertical breathing room to the Qibla compass dial on standard screens.
- App-Wide Portrait Mode Locking:
  - Disallowed landscape rotation across the entire app.
  - Added `SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown])` in `main.dart`.
  - Configured `android:screenOrientation="portrait"` on `MainActivity` in `AndroidManifest.xml`.
  - Removed `UIInterfaceOrientationLandscapeLeft` and `UIInterfaceOrientationLandscapeRight` from iOS `Info.plist`.

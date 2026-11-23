# Silah — Masjid Community App

Silah connects worshippers with their local masjid and gives masjid teams tools to manage prayer schedules, announcements, members, and community contributions.

## Project layout

- `app/` — Flutter app for Android, iOS, web, and desktop targets.
- `backend/` — NestJS REST API with Prisma and PostgreSQL.

## App features

- Phone sign-in, profile onboarding, and masjid administrator onboarding.
- Masjid search, QR connection, and saved primary masjid.
- Daily prayer and jama'ah schedules, announcements, and push notifications.
- Qibla compass, Quran chapter reader with Arabic and English text, and saved reading position.
- Sandha plan status and separate masjid and super administrator dashboards.

## Run the Flutter app

```sh
cd app
flutter pub get
flutter run
```

The app currently connects to the configured Silah API in `app/lib/core/network/api_service.dart`. Quran chapter and verse text is loaded from [AlQuran Cloud](https://alquran.cloud/api); the reader needs an internet connection.

## Run the backend locally

```sh
cd backend
npm install
cp .env.example .env
npm run prisma:generate
npm run start:dev
```

Set `DATABASE_URL` and the JWT secrets in `backend/.env` for your environment. The API uses the `/v1` prefix; Swagger is served at `/v1/docs` when the backend is running. Configure a real OTP provider and Firebase Admin credentials (`FIREBASE_SERVICE_ACCOUNT_JSON`, or Application Default Credentials) before using push notifications. Keep the service-account secret in your deployment secret manager, not in source control.

## Build checks

From `app/`, run `flutter analyze`. From `backend/`, run `npm run build`.

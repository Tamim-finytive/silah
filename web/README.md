# Silah Super Admin Portal

A static, responsive web portal for the existing Silah Super Admin APIs. The portal uses the live NestJS backend for sign-in, dashboard metrics, masjid requests and directory, user management, and global broadcasts. It contains no demo or placeholder business records.

## Local preview

Serve this folder with any static file server and open its `index.html`. There is no build step or dependency install. Set `apiBaseUrl` in `config.js` to point the portal at a different Silah `/v1` API before serving it.

## Deploy to Vercel

1. Import this repository into Vercel.
2. Set the project **Root Directory** to `web`.
3. Select **Other** as the framework preset. Leave the build command empty and use `.` as the output directory.
4. Deploy. `vercel.json` supplies basic browser security headers.

The production API URL is configured in `config.js`; change it to the intended deployed backend before publishing to another environment. The backend must allow the deployed portal origin in CORS if its CORS policy is restricted. Current API CORS allows browser requests.

## Sign-in and data

- Sign in with a phone number already assigned Super Admin access, using the backend OTP flow. The portal verifies the signed-in profile through `/auth/me` before showing admin data.
- Access and refresh tokens are held in `sessionStorage` for the current browser tab and removed on sign-out.
- Directory and user lists load 20 records at a time as the table scrolls. Masjid filters are sent to the backend, including status, approval, sort order, and created-date range.
- Changes (approve/reject, create, activate/deactivate, delete, and broadcast) call the existing authenticated APIs and persist through the backend database.
- Push delivery for broadcasts depends on backend Firebase configuration and recipients' registered devices and notification permissions.

The portal does not include backend secrets. Use the backend's normal Super Admin account and deployment environment configuration.

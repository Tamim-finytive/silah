# API Contract — Masjid Management & Namaz Time

## Base URL

```
https://api.masjidapp.com/api/v1
```

## Standard Response Envelope

### Success Response

```json
{
  "success": true,
  "data": { ... },
  "meta": {                    // present only on paginated endpoints
    "page": 1,
    "limit": 20,
    "total": 150,
    "totalPages": 8
  }
}
```

### Error Response

```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Human-readable message",
    "details": [ ... ],        // optional: field-level errors
    "timestamp": "ISO-8601",
    "path": "/api/v1/...",
    "requestId": "req_xxx"
  }
}
```

## Pagination Strategy

- Query params: `?page=1&limit=20`
- Default: `page=1`, `limit=20`
- Max limit: `100`
- Response includes `meta` object with `page`, `limit`, `total`, `totalPages`
- Cursor-based pagination available for high-volume endpoints (future, documented per endpoint)

## Authentication

- All protected endpoints require `Authorization: Bearer <access_token>` header.
- Endpoints marked 🔓 are public (no auth required).
- Role requirements are listed per endpoint.

---

## 1. Auth Module

### POST /auth/request-otp 🔓

Request OTP for login/registration.

| Field | Detail |
|-------|--------|
| **Auth** | None |
| **Roles** | Any |

**Request Body**:
```json
{
  "phone": "+919876543210"
}
```

**Response** (200):
```json
{
  "success": true,
  "data": {
    "message": "OTP sent successfully",
    "expiresInSeconds": 300,
    "retryAfterSeconds": 60
  }
}
```

**Errors**: `400 VALIDATION_ERROR` (invalid phone), `429 RATE_LIMITED` (too many OTP requests)

---

### POST /auth/verify-otp 🔓

Verify OTP and get tokens. Creates user if first login.

| Field | Detail |
|-------|--------|
| **Auth** | None |
| **Roles** | Any |

**Request Body**:
```json
{
  "phone": "+919876543210",
  "otp": "123456",
  "deviceToken": "fcm_token_xxx",
  "platform": "ANDROID",
  "name": "Mohammed Ali"
}
```

> `name` is required only for first-time registration (new phone number). `deviceToken` and `platform` are optional but recommended for push notifications.

**Response** (200):
```json
{
  "success": true,
  "data": {
    "accessToken": "eyJ...",
    "refreshToken": "rt_xxx",
    "expiresIn": 900,
    "user": {
      "id": "uuid",
      "phone": "+919876543210",
      "name": "Mohammed Ali",
      "language": "en",
      "isSuperAdmin": false,
      "isNewUser": true
    }
  }
}
```

**Errors**: `400 VALIDATION_ERROR`, `401 OTP_INVALID`, `401 OTP_EXPIRED`

---

### POST /auth/refresh-token

Refresh access token.

| Field | Detail |
|-------|--------|
| **Auth** | None (refresh token in body) |
| **Roles** | Any authenticated |

**Request Body**:
```json
{
  "refreshToken": "rt_xxx"
}
```

**Response** (200):
```json
{
  "success": true,
  "data": {
    "accessToken": "eyJ...",
    "refreshToken": "rt_new_xxx",
    "expiresIn": 900
  }
}
```

**Errors**: `401 UNAUTHORIZED` (invalid/expired refresh token)

---

### POST /auth/logout

Invalidate refresh token and unregister device.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Any authenticated |

**Request Body**:
```json
{
  "refreshToken": "rt_xxx",
  "deviceToken": "fcm_token_xxx"
}
```

**Response** (200):
```json
{
  "success": true,
  "data": {
    "message": "Logged out successfully"
  }
}
```

---

## 2. Users Module

### GET /users/me

Get current user's profile.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Any authenticated |

**Response** (200):
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "phone": "+919876543210",
    "name": "Mohammed Ali",
    "avatarUrl": null,
    "language": "en",
    "isSuperAdmin": false,
    "createdAt": "2024-01-15T10:30:00Z",
    "memberships": [
      {
        "id": "uuid",
        "masjidId": "uuid",
        "masjidName": "Masjid Al-Huda",
        "isPrimary": true,
        "joinedAt": "2024-01-15T10:35:00Z"
      }
    ],
    "roles": [
      {
        "masjidId": "uuid",
        "masjidName": "Masjid Al-Huda",
        "role": "ADMIN"
      }
    ]
  }
}
```

---

### PATCH /users/me

Update current user's profile.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Any authenticated |

**Request Body** (all fields optional):
```json
{
  "name": "Mohammed Ali Khan",
  "language": "ta",
  "avatarUrl": "https://storage.../avatar.jpg"
}
```

**Response** (200): Updated user object (same shape as GET /users/me).

**Errors**: `400 VALIDATION_ERROR`

---

### DELETE /users/me

Deactivate (soft-delete) own account.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Any authenticated |

**Response** (200):
```json
{
  "success": true,
  "data": { "message": "Account deactivated" }
}
```

---

### GET /users (Super Admin)

List all users with pagination.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Super Admin |

**Query Params**: `?page=1&limit=20&search=ali&isActive=true`

**Response** (200):
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "phone": "+919876543210",
      "name": "Mohammed Ali",
      "language": "en",
      "isActive": true,
      "createdAt": "2024-01-15T10:30:00Z",
      "membershipCount": 2
    }
  ],
  "meta": { "page": 1, "limit": 20, "total": 500, "totalPages": 25 }
}
```

---

### GET /users/:id (Super Admin)

Get any user's profile.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Super Admin |

**Response** (200): Same shape as GET /users/me.

**Errors**: `404 NOT_FOUND`

---

### POST /users (Super Admin)

Create a user.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Super Admin |

**Request Body**:
```json
{
  "phone": "+919876543210",
  "name": "New User",
  "language": "ta"
}
```

**Response** (201): Created user object.

**Errors**: `400 VALIDATION_ERROR`, `409 CONFLICT` (phone already registered)

---

### PATCH /users/:id/deactivate (Super Admin)

Deactivate any user.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Super Admin |

**Response** (200):
```json
{
  "success": true,
  "data": { "message": "User deactivated" }
}
```

---

## 3. Masjids Module

### GET /masjids 🔓

List/search masjids.

| Field | Detail |
|-------|--------|
| **Auth** | Optional |
| **Roles** | Any (including guest) |

**Query Params**: `?page=1&limit=20&search=huda&city=Tirunelveli&lat=8.71&lng=77.68&radius=10`

**Response** (200):
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "name": "Masjid Al-Huda",
      "nameTa": "மஸ்ஜிதுல் ஹுதா",
      "address": "123 Main Street, Melapalayam",
      "city": "Tirunelveli",
      "latitude": 8.7139,
      "longitude": 77.6872,
      "photoUrl": null,
      "memberCount": 150,
      "distanceKm": 2.5
    }
  ],
  "meta": { "page": 1, "limit": 20, "total": 45, "totalPages": 3 }
}
```

> `distanceKm` is included only when `lat` and `lng` are provided. Results sorted by distance in that case.

---

### GET /masjids/:id 🔓

Get masjid details.

| Field | Detail |
|-------|--------|
| **Auth** | Optional |
| **Roles** | Any (including guest) |

**Response** (200):
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "name": "Masjid Al-Huda",
    "nameTa": "மஸ்ஜிதுல் ஹுதா",
    "address": "123 Main Street, Melapalayam",
    "latitude": 8.7139,
    "longitude": 77.6872,
    "city": "Tirunelveli",
    "state": "Tamil Nadu",
    "country": "India",
    "phone": "+914622345678",
    "photoUrl": null,
    "memberCount": 150,
    "isActive": true,
    "createdAt": "2024-01-10T08:00:00Z",
    "todayPrayerTimes": {
      "fajrJamaah": "05:30",
      "dhuhrJamaah": "12:45",
      "asrJamaah": "16:00",
      "maghribJamaah": "18:15",
      "ishaJamaah": "19:45"
    }
  }
}
```

---

### POST /masjids

Create a new masjid. Creator automatically becomes Admin.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Super Admin, Admin (self-registers) |

**Request Body**:
```json
{
  "name": "Masjid Al-Falah",
  "nameTa": "மஸ்ஜிதுல் ஃபலாஹ்",
  "address": "789 New Road, Palayamkottai",
  "latitude": 8.7225,
  "longitude": 77.7284,
  "city": "Tirunelveli",
  "state": "Tamil Nadu",
  "country": "India",
  "phone": "+914622345679"
}
```

**Response** (201): Created masjid object with `qrToken` generated.

**Errors**: `400 VALIDATION_ERROR`

---

### PATCH /masjids/:id

Update masjid details.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Super Admin, Admin (own masjid only) |

**Request Body** (all fields optional):
```json
{
  "name": "Masjid Al-Huda Updated",
  "address": "New address",
  "phone": "+914622345680"
}
```

**Response** (200): Updated masjid object.

**Errors**: `403 FORBIDDEN` (not admin of this masjid), `404 NOT_FOUND`

---

### DELETE /masjids/:id (Super Admin)

Delete (soft-deactivate) a masjid.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Super Admin |

**Response** (200):
```json
{
  "success": true,
  "data": { "message": "Masjid deactivated" }
}
```

---

### POST /masjids/:id/regenerate-qr

Regenerate QR token.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Super Admin, Admin (own masjid only) |

**Request Body** (optional):
```json
{
  "expiresInDays": 30
}
```

> Omit `expiresInDays` for permanent token.

**Response** (200):
```json
{
  "success": true,
  "data": {
    "qrToken": "new_random_token_xxx",
    "qrUrl": "https://masjidapp.com/join/new_random_token_xxx",
    "expiresAt": null
  }
}
```

---

### POST /masjids/:id/upload-photo

Get pre-signed upload URL for masjid photo.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Super Admin, Admin (own masjid only) |

**Request Body**:
```json
{
  "contentType": "image/jpeg",
  "fileName": "masjid-front.jpg"
}
```

**Response** (200):
```json
{
  "success": true,
  "data": {
    "uploadUrl": "https://storage.../presigned-url",
    "publicUrl": "https://storage.../masjids/uuid/masjid-front.jpg",
    "expiresInSeconds": 300
  }
}
```

---

## 4. Memberships Module

### POST /memberships/join-by-qr

Join a masjid by QR token.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Any authenticated |

**Request Body**:
```json
{
  "qrToken": "join_alhuda_2024_permanent"
}
```

**Response** (201):
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "masjidId": "uuid",
    "masjidName": "Masjid Al-Huda",
    "isPrimary": false,
    "joinedAt": "2024-01-15T10:35:00Z"
  }
}
```

**Errors**: `404 NOT_FOUND` (invalid token), `401 OTP_EXPIRED` (token expired), `409 CONFLICT` (already a member)

---

### POST /memberships/join

Join a masjid by masjid ID (search-based join).

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Any authenticated |

**Request Body**:
```json
{
  "masjidId": "uuid"
}
```

**Response** (201): Same as join-by-qr.

**Errors**: `404 NOT_FOUND`, `409 CONFLICT`

---

### DELETE /memberships/:id

Leave a masjid.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Any authenticated (own membership) |

**Response** (200):
```json
{
  "success": true,
  "data": { "message": "Left masjid successfully" }
}
```

---

### GET /memberships/me

List current user's memberships.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Any authenticated |

**Response** (200):
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "masjidId": "uuid",
      "masjidName": "Masjid Al-Huda",
      "masjidNameTa": "மஸ்ஜிதுல் ஹுதா",
      "isPrimary": true,
      "joinedAt": "2024-01-15T10:35:00Z"
    }
  ]
}
```

---

### PATCH /memberships/:id/set-primary

Set a membership as primary.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Any authenticated (own membership) |

**Response** (200):
```json
{
  "success": true,
  "data": { "message": "Primary masjid updated" }
}
```

---

### GET /masjids/:id/members

List masjid members.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Super Admin, Admin (own masjid), Finance (own masjid) |

**Query Params**: `?page=1&limit=20&search=ali`

**Response** (200):
```json
{
  "success": true,
  "data": [
    {
      "membershipId": "uuid",
      "userId": "uuid",
      "name": "Mohammed Ali",
      "phone": "+919876543210",
      "joinedAt": "2024-01-15T10:35:00Z"
    }
  ],
  "meta": { "page": 1, "limit": 20, "total": 150, "totalPages": 8 }
}
```

---

### DELETE /masjids/:id/members/:membershipId

Remove a member from masjid.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Super Admin, Admin (own masjid) |

**Response** (200):
```json
{
  "success": true,
  "data": { "message": "Member removed" }
}
```

---

## 5. Prayer Times Module

### GET /masjids/:id/prayer-times 🔓

Get prayer times for a masjid.

| Field | Detail |
|-------|--------|
| **Auth** | Optional |
| **Roles** | Any (including guest) |

**Query Params**: `?date=2024-01-15` or `?startDate=2024-01-15&endDate=2024-01-21` (week view)

**Response** (200):
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "date": "2024-01-15",
      "fajrAdhan": "05:15",
      "fajrJamaah": "05:30",
      "dhuhrAdhan": "12:30",
      "dhuhrJamaah": "12:45",
      "asrAdhan": "15:45",
      "asrJamaah": "16:00",
      "maghribAdhan": "18:00",
      "maghribJamaah": "18:15",
      "ishaAdhan": "19:30",
      "ishaJamaah": "19:45",
      "jummahKhutbah": "12:30",
      "jummahJamaah": "12:50",
      "updatedAt": "2024-01-14T18:00:00Z"
    }
  ]
}
```

> If no times set for the requested date, returns empty array. Client should show "Times not yet announced."

---

### PUT /masjids/:id/prayer-times

Set prayer times for a specific date.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Super Admin, Admin (own masjid) |

**Request Body**:
```json
{
  "date": "2024-01-15",
  "fajrAdhan": "05:15",
  "fajrJamaah": "05:30",
  "dhuhrAdhan": "12:30",
  "dhuhrJamaah": "12:45",
  "asrAdhan": "15:45",
  "asrJamaah": "16:00",
  "maghribAdhan": "18:00",
  "maghribJamaah": "18:15",
  "ishaAdhan": "19:30",
  "ishaJamaah": "19:45",
  "jummahKhutbah": "12:30",
  "jummahJamaah": "12:50"
}
```

> Adhan times and Jummah times are optional. Jamaah times for the 5 prayers are required.

**Response** (200): Created/updated prayer time object.

**Errors**: `400 VALIDATION_ERROR`, `403 FORBIDDEN`

---

### PUT /masjids/:id/prayer-times/bulk

Set prayer times for a date range (copy same times across multiple days).

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Super Admin, Admin (own masjid) |

**Request Body**:
```json
{
  "startDate": "2024-01-15",
  "endDate": "2024-01-21",
  "times": {
    "fajrJamaah": "05:30",
    "dhuhrJamaah": "12:45",
    "asrJamaah": "16:00",
    "maghribJamaah": "18:15",
    "ishaJamaah": "19:45"
  }
}
```

**Response** (200):
```json
{
  "success": true,
  "data": { "message": "Prayer times set for 7 days", "count": 7 }
}
```

---

### PUT /prayer-times/region-defaults (Super Admin)

Set region-wide default prayer times.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Super Admin |

**Request Body**:
```json
{
  "city": "Tirunelveli",
  "date": "2024-01-15",
  "times": {
    "fajrJamaah": "05:30",
    "dhuhrJamaah": "12:45",
    "asrJamaah": "16:00",
    "maghribJamaah": "18:15",
    "ishaJamaah": "19:45"
  },
  "applyToMasjids": true
}
```

> If `applyToMasjids` is true, sets these times for all masjids in the city that haven't set their own times for this date.

**Response** (200):
```json
{
  "success": true,
  "data": { "message": "Default times set", "masjidsUpdated": 12 }
}
```

---

## 6. Special Schedules Module

### GET /masjids/:id/special-schedules 🔓

List special schedules for a masjid.

| Field | Detail |
|-------|--------|
| **Auth** | Optional |
| **Roles** | Any (including guest) |

**Query Params**: `?type=RAMZAN_TIMETABLE&startDate=2024-03-11&endDate=2024-04-09`

**Response** (200):
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "type": "TARAWEEH",
      "title": "Taraweeh Prayers",
      "titleTa": "தராவீஹ் தொழுகை",
      "startDate": "2024-03-11",
      "endDate": "2024-04-09",
      "startTime": "20:30",
      "endTime": "22:00",
      "notes": "20 rakaat with Quran khatm",
      "notesTa": "குர்ஆன் கத்மடன் 20 ரக்அத்",
      "createdAt": "2024-03-01T10:00:00Z"
    }
  ]
}
```

---

### POST /masjids/:id/special-schedules

Create a special schedule.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Super Admin, Admin (own masjid) |

**Request Body**:
```json
{
  "type": "TARAWEEH",
  "title": "Taraweeh Prayers",
  "titleTa": "தராவீஹ் தொழுகை",
  "startDate": "2024-03-11",
  "endDate": "2024-04-09",
  "startTime": "20:30",
  "endTime": "22:00",
  "notes": "20 rakaat with Quran khatm",
  "notesTa": "குர்ஆன் கத்மடன் 20 ரக்அத்"
}
```

**Response** (201): Created schedule object.

**Errors**: `400 VALIDATION_ERROR`, `403 FORBIDDEN`, `422 UNPROCESSABLE` (endDate before startDate)

---

### PATCH /masjids/:id/special-schedules/:scheduleId

Update a special schedule.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Super Admin, Admin (own masjid) |

**Request Body**: Partial fields to update.

**Response** (200): Updated schedule object.

---

### DELETE /masjids/:id/special-schedules/:scheduleId

Delete a special schedule.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Super Admin, Admin (own masjid) |

**Response** (200):
```json
{
  "success": true,
  "data": { "message": "Schedule deleted" }
}
```

---

## 7. Announcements Module

### GET /masjids/:id/announcements 🔓

List announcements for a masjid.

| Field | Detail |
|-------|--------|
| **Auth** | Optional |
| **Roles** | Any (including guest) |

**Query Params**: `?page=1&limit=20&category=GENERAL`

**Response** (200):
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "category": "GENERAL",
      "title": "Friday Lecture Topic",
      "titleTa": "வெள்ளி சொற்பொழிவு தலைப்பு",
      "body": "This week's lecture: Importance of Salah",
      "bodyTa": "இந்த வார சொற்பொழிவு: தொழுகையின் முக்கியத்துவம்",
      "isPinned": false,
      "publishedAt": "2024-01-15T08:00:00Z",
      "expiresAt": null,
      "createdBy": {
        "id": "uuid",
        "name": "Imam Ibrahim"
      }
    }
  ],
  "meta": { "page": 1, "limit": 20, "total": 35, "totalPages": 2 }
}
```

> Pinned announcements are always returned first, regardless of sort order.

---

### GET /masjids/:id/announcements/:announcementId 🔓

Get single announcement.

| Field | Detail |
|-------|--------|
| **Auth** | Optional |
| **Roles** | Any (including guest) |

**Response** (200): Full announcement object.

---

### POST /masjids/:id/announcements

Create an announcement.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Super Admin, Admin (own masjid), Announcement (own masjid) |

**Request Body**:
```json
{
  "category": "EVENT",
  "title": "Annual Quran Competition",
  "titleTa": "ஆண்டு குர்ஆன் போட்டி",
  "body": "Register before January 20th for the annual Quran recitation competition.",
  "bodyTa": "ஆண்டு குர்ஆன் ஓதல் போட்டிக்கு ஜனவரி 20ம் தேதிக்கு முன் பதிவு செய்யவும்.",
  "isPinned": false,
  "notifyPush": true,
  "expiresAt": "2024-01-25T23:59:59Z"
}
```

**Response** (201): Created announcement object.

**Errors**: `400 VALIDATION_ERROR`, `403 FORBIDDEN`

---

### PATCH /masjids/:id/announcements/:announcementId

Update an announcement.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Super Admin, Admin (own masjid), Announcement (own masjid) |

**Request Body**: Partial fields to update.

**Response** (200): Updated announcement object.

---

### DELETE /masjids/:id/announcements/:announcementId

Delete an announcement.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Super Admin, Admin (own masjid) |

**Response** (200):
```json
{
  "success": true,
  "data": { "message": "Announcement deleted" }
}
```

---

### PATCH /masjids/:id/announcements/:announcementId/pin

Pin or unpin an announcement.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Super Admin, Admin (own masjid) |

**Request Body**:
```json
{
  "isPinned": true
}
```

**Response** (200): Updated announcement object.

---

## 8. Sandha (Dues) Module

### GET /masjids/:id/sandha-plans

List sandha plans for a masjid.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Super Admin, Admin (own masjid), Finance (own masjid) |

**Response** (200):
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "name": "Monthly Maintenance",
      "amount": 100.00,
      "frequency": "MONTHLY",
      "description": "Monthly masjid maintenance contribution",
      "isActive": true,
      "memberCount": 85,
      "collectedThisMonth": 6500.00,
      "pendingThisMonth": 2000.00
    }
  ]
}
```

---

### POST /masjids/:id/sandha-plans

Create a sandha plan.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Super Admin, Admin (own masjid), Finance (own masjid) |

**Request Body**:
```json
{
  "name": "Monthly Maintenance",
  "amount": 100.00,
  "frequency": "MONTHLY",
  "description": "Monthly masjid maintenance contribution"
}
```

**Response** (201): Created plan object.

---

### PATCH /masjids/:id/sandha-plans/:planId

Update a sandha plan.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Super Admin, Admin (own masjid), Finance (own masjid) |

**Request Body**: Partial fields.

**Response** (200): Updated plan object.

---

### DELETE /masjids/:id/sandha-plans/:planId

Delete a sandha plan.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Super Admin, Admin (own masjid) |

**Response** (200):
```json
{
  "success": true,
  "data": { "message": "Plan deleted" }
}
```

---

### GET /masjids/:id/sandha-plans/:planId/members

List members enrolled in a plan.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Super Admin, Admin (own masjid), Finance (own masjid) |

**Query Params**: `?page=1&limit=20&search=ali&linked=true`

**Response** (200):
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "phone": "+919876543210",
      "name": "Mohammed Ali",
      "userId": "uuid",
      "autoLinked": true,
      "linkedAt": "2024-01-15T10:30:00Z",
      "lastPayment": {
        "amount": 100.00,
        "paidAt": "2024-01-05T14:00:00Z",
        "periodEnd": "2024-01-31"
      },
      "isPaidCurrentPeriod": true
    }
  ],
  "meta": { "page": 1, "limit": 20, "total": 85, "totalPages": 5 }
}
```

---

### POST /masjids/:id/sandha-plans/:planId/members

Add a member to a sandha plan. Triggers auto-link check.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Super Admin, Admin (own masjid), Finance (own masjid) |

**Request Body**:
```json
{
  "phone": "+919876543210",
  "name": "Mohammed Ali"
}
```

**Response** (201):
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "phone": "+919876543210",
    "name": "Mohammed Ali",
    "userId": "uuid",
    "autoLinked": true,
    "linkedAt": "2024-01-15T10:30:00Z"
  }
}
```

> `userId` and `autoLinked` populated if phone matches a registered user.

**Errors**: `409 CONFLICT` (phone already in this plan)

---

### DELETE /masjids/:id/sandha-plans/:planId/members/:memberId

Remove a member from a plan.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Super Admin, Admin (own masjid), Finance (own masjid) |

**Response** (200):
```json
{
  "success": true,
  "data": { "message": "Member removed from plan" }
}
```

---

### POST /masjids/:id/sandha-plans/:planId/payments

Record a payment.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Super Admin, Admin (own masjid), Finance (own masjid) |

**Request Body**:
```json
{
  "planMemberId": "uuid",
  "amount": 100.00,
  "status": "PAID",
  "method": "CASH",
  "receiptNumber": "REC-2024-001",
  "periodStart": "2024-01-01",
  "periodEnd": "2024-01-31",
  "paidAt": "2024-01-05T14:00:00Z",
  "notes": "Paid in full"
}
```

**Response** (201): Created payment object.

**Errors**: `400 VALIDATION_ERROR`, `422 UNPROCESSABLE` (periodEnd before periodStart)

---

### GET /masjids/:id/sandha-plans/:planId/payments

List payments for a plan.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Super Admin, Admin (own masjid), Finance (own masjid) |

**Query Params**: `?page=1&limit=20&status=PAID&startDate=2024-01-01&endDate=2024-01-31&memberId=uuid`

**Response** (200):
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "planMember": {
        "id": "uuid",
        "name": "Mohammed Ali",
        "phone": "+919876543210"
      },
      "amount": 100.00,
      "status": "PAID",
      "method": "CASH",
      "receiptNumber": "REC-2024-001",
      "periodStart": "2024-01-01",
      "periodEnd": "2024-01-31",
      "paidAt": "2024-01-05T14:00:00Z",
      "recordedBy": {
        "id": "uuid",
        "name": "Imam Ibrahim"
      }
    }
  ],
  "meta": { "page": 1, "limit": 20, "total": 85, "totalPages": 5 }
}
```

---

### GET /sandha/my-dues

Get current user's sandha status across all masjids.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Any authenticated |

**Response** (200):
```json
{
  "success": true,
  "data": [
    {
      "masjidId": "uuid",
      "masjidName": "Masjid Al-Huda",
      "plans": [
        {
          "planId": "uuid",
          "planName": "Monthly Maintenance",
          "amount": 100.00,
          "frequency": "MONTHLY",
          "isPaidCurrentPeriod": true,
          "lastPayment": {
            "amount": 100.00,
            "paidAt": "2024-01-05T14:00:00Z",
            "periodEnd": "2024-01-31"
          }
        }
      ]
    }
  ]
}
```

---

### GET /masjids/:id/sandha-reports

Get sandha collection reports.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Super Admin, Admin (own masjid), Finance (own masjid) |

**Query Params**: `?startDate=2024-01-01&endDate=2024-12-31&groupBy=month`

**Response** (200):
```json
{
  "success": true,
  "data": {
    "summary": {
      "totalCollected": 78000.00,
      "totalPending": 12000.00,
      "totalMembers": 85,
      "paidMembers": 65,
      "collectionRate": 76.5
    },
    "breakdown": [
      {
        "period": "2024-01",
        "collected": 6500.00,
        "pending": 2000.00,
        "paidCount": 65,
        "totalCount": 85
      }
    ]
  }
}
```

---

## 9. Devices & Notifications Module

### POST /devices

Register a device for push notifications.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Any authenticated |

**Request Body**:
```json
{
  "fcmToken": "fcm_token_xxx",
  "platform": "ANDROID"
}
```

**Response** (201):
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "fcmToken": "fcm_token_xxx",
    "platform": "ANDROID"
  }
}
```

> Upserts: if token already exists for this user, updates it.

---

### PUT /devices/:deviceId

Update device token (on FCM token refresh).

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Any authenticated (own device) |

**Request Body**:
```json
{
  "fcmToken": "new_fcm_token_xxx"
}
```

**Response** (200): Updated device object.

---

### GET /notifications/prefs

Get notification preferences for all joined masjids.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Any authenticated |

**Response** (200):
```json
{
  "success": true,
  "data": [
    {
      "masjidId": "uuid",
      "masjidName": "Masjid Al-Huda",
      "allAnnouncements": true,
      "prayerChanges": true,
      "emergencyAlerts": true,
      "sandhaReminders": true
    }
  ]
}
```

---

### PATCH /notifications/prefs/:masjidId

Update notification preferences for a masjid.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Any authenticated |

**Request Body**:
```json
{
  "allAnnouncements": false,
  "prayerChanges": true,
  "sandhaReminders": false
}
```

> `emergencyAlerts` cannot be set to false (always true, enforced server-side).

**Response** (200): Updated preferences object.

---

## 10. Qibla Module

> Qibla direction is calculated **entirely on the client** using the device's GPS coordinates and compass sensor. No backend API is needed.
>
> **Formula**: The bearing from the user's location to the Kaaba (21.4225°N, 39.8262°E) is computed using the great-circle bearing formula. The Flutter app uses the `flutter_compass` and `geolocator` packages.

---

## 11. Admin Dashboard Module

### GET /admin/masjids/:id/dashboard

Get dashboard stats for a masjid.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Super Admin, Admin (own masjid) |

**Response** (200):
```json
{
  "success": true,
  "data": {
    "memberCount": 150,
    "newMembersThisMonth": 12,
    "announcementCount": 35,
    "activeSandhaPlans": 2,
    "sandhaCollectionThisMonth": 6500.00,
    "sandhaPendingThisMonth": 2000.00,
    "prayerTimesSetUntil": "2024-01-21"
  }
}
```

---

### GET /admin/masjids/:id/roles

List users with custom roles for a masjid.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Super Admin, Admin (own masjid) |

**Response** (200):
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "userId": "uuid",
      "userName": "Ahmed Finance",
      "userPhone": "+919876543211",
      "role": "FINANCE",
      "createdAt": "2024-01-10T10:00:00Z"
    }
  ]
}
```

---

### POST /admin/masjids/:id/roles

Assign a custom role to a user.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Super Admin, Admin (own masjid) |

**Request Body**:
```json
{
  "userId": "uuid",
  "role": "FINANCE"
}
```

> `role` must be one of: `FINANCE`, `ANNOUNCEMENT`. Admin role can only be assigned by Super Admin.

**Response** (201): Created role assignment object.

**Errors**: `400 VALIDATION_ERROR`, `409 CONFLICT` (user already has this role for this masjid)

---

### DELETE /admin/masjids/:id/roles/:roleAssignmentId

Revoke a custom role.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Super Admin, Admin (own masjid) |

**Response** (200):
```json
{
  "success": true,
  "data": { "message": "Role revoked" }
}
```

---

## 12. Super Admin Dashboard Module

### GET /super-admin/dashboard

Get platform-wide statistics.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Super Admin |

**Response** (200):
```json
{
  "success": true,
  "data": {
    "totalMasjids": 45,
    "totalUsers": 2500,
    "totalMemberships": 3200,
    "activeMasjids": 42,
    "newUsersThisMonth": 120,
    "newMasjidsThisMonth": 3,
    "totalSandhaCollectedThisMonth": 125000.00,
    "topMasjidsByMembers": [
      { "id": "uuid", "name": "Masjid Al-Huda", "memberCount": 150 }
    ]
  }
}
```

---

### GET /super-admin/masjids

List all masjids with admin info.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Super Admin |

**Query Params**: `?page=1&limit=20&search=huda&city=Tirunelveli&isActive=true`

**Response** (200):
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "name": "Masjid Al-Huda",
      "city": "Tirunelveli",
      "memberCount": 150,
      "adminCount": 1,
      "isActive": true,
      "createdAt": "2024-01-10T08:00:00Z",
      "admins": [
        { "id": "uuid", "name": "Imam Ibrahim", "phone": "+919999900002" }
      ]
    }
  ],
  "meta": { "page": 1, "limit": 20, "total": 45, "totalPages": 3 }
}
```

---

### POST /super-admin/masjids/:id/admins

Assign an admin to a masjid (Super Admin invite).

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Super Admin |

**Request Body**:
```json
{
  "userId": "uuid"
}
```

**Response** (201): Created admin assignment.

**Errors**: `404 NOT_FOUND` (user or masjid), `409 CONFLICT` (already admin)

---

### GET /super-admin/sandha-payers

List all sandha payers across all masjids.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Super Admin |

**Query Params**: `?page=1&limit=20&masjidId=uuid&status=PENDING`

**Response** (200):
```json
{
  "success": true,
  "data": [
    {
      "userId": "uuid",
      "userName": "Mohammed Ali",
      "phone": "+919876543210",
      "masjidName": "Masjid Al-Huda",
      "planName": "Monthly Maintenance",
      "lastPaymentDate": "2024-01-05",
      "isPaidCurrentPeriod": true
    }
  ],
  "meta": { "page": 1, "limit": 20, "total": 500, "totalPages": 25 }
}
```

---

### GET /super-admin/analytics

Get platform analytics.

| Field | Detail |
|-------|--------|
| **Auth** | Bearer token |
| **Roles** | Super Admin |

**Query Params**: `?period=monthly&startDate=2024-01-01&endDate=2024-12-31`

**Response** (200):
```json
{
  "success": true,
  "data": {
    "userGrowth": [
      { "period": "2024-01", "newUsers": 120, "totalUsers": 2500 }
    ],
    "masjidGrowth": [
      { "period": "2024-01", "newMasjids": 3, "totalMasjids": 45 }
    ],
    "membershipGrowth": [
      { "period": "2024-01", "newMemberships": 180, "totalMemberships": 3200 }
    ],
    "sandhaCollection": [
      { "period": "2024-01", "totalCollected": 125000.00, "totalPending": 35000.00 }
    ]
  }
}
```

---

## Error Code Reference

| HTTP Status | Error Code | Description |
|-------------|-----------|-------------|
| 400 | `VALIDATION_ERROR` | Request body / query param validation fails |
| 401 | `UNAUTHORIZED` | Missing or invalid JWT |
| 401 | `OTP_EXPIRED` | OTP TTL exceeded (5 min) |
| 401 | `OTP_INVALID` | Wrong OTP code |
| 403 | `FORBIDDEN` | Valid JWT but insufficient role/permission |
| 404 | `NOT_FOUND` | Resource does not exist |
| 409 | `CONFLICT` | Duplicate resource (already a member, phone registered, etc.) |
| 422 | `UNPROCESSABLE` | Semantically invalid (endDate < startDate, etc.) |
| 429 | `RATE_LIMITED` | Too many requests |
| 500 | `INTERNAL_ERROR` | Unhandled server error |

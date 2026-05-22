# BRIMOON Studio Mobile

Flutter mobile app for BRIMOON Studio, connected to the Django REST API.

Base API URL: `https://anna.listoya.es/api/v1/`

## Current Capabilities

### Authentication and Roles

- Basic Auth login against the mobile API.
- Secure local credential storage for session restore.
- `/me/` profile validation on startup.
- Role-based app shell:
  - `owner/admin`: salon management mode.
  - `employee`: own work profile mode.
  - `client`: client portal mode.
- Account settings:
  - edit own name/email;
  - change password;
  - sign out.

### Branding and Appearance

- BRIMOON Studio name across mobile/web/desktop labels.
- BRIMOON logo as in-app asset and launcher icon.
- Customizable app primary color.
- Adjustable app font scale.
- Persistent local calendar employee filter.

### Calendar

- Day and employee calendar modes.
- Multi-employee filter with persisted selection.
- Empty slot tap opens action chooser:
  - new booking;
  - new pause/block.
- Booking creation from a tapped slot pre-fills date, time, and employee.
- Drag-and-drop booking reschedule without confirmation dialog.
- Calendar refresh and booking highlight after create/reschedule.
- Time blocks:
  - one-time block;
  - weekly recurrence;
  - weekday recurrence;
  - editable manual blocks;
  - schedule breaks shown as non-editable.
- Backend availability errors are shown clearly.

### Bookings

- Booking form with:
  - client selection and quick client creation;
  - booking source/origin;
  - service filtered by selected employee;
  - employee filtered by selected service;
  - zone selection when service requires it;
  - availability slot selector;
  - notes;
  - before/after photos.
- Dropdown safety:
  - duplicate options are deduplicated;
  - invalid selected values are cleared before rendering.
- Booking details and editing from calendar.
- Booking status updates.
- Fullscreen photo preview with zoom.
- Local selected booking photos can be shared via system share sheet before upload.

### Clients

- Client list with search.
- Create/edit client cards.
- Optional client portal access credentials from the client form.
- Full client profile:
  - visits;
  - total spent;
  - average ticket;
  - referral counts and reward progress;
  - contact details;
  - last/next booking;
  - favorite services;
  - favorite employees;
  - visual photo history;
  - referral tree;
  - referred clients;
  - booking history.
- Clickable phone/email:
  - call;
  - WhatsApp;
  - email.
- Clickable linked employees, referrals, and bookings.

### Employees

- Employee list and full employee cards.
- Admin can create/edit employees.
- Employee account login support.
- Employee self-profile editing without seeing commission.
- Employee can choose own provided services.
- Admin can set:
  - login username/password;
  - commission;
  - active state;
  - service list;
  - calendar color from palette.
- Employee analytics:
  - bookings;
  - clients;
  - revenue;
  - common services and clients.

### Services and Zones

- Service list and zone list.
- Create/edit services.
- Create/edit zones.
- Assign zones to services.
- Service and zone color palette selectors.
- Manual card UI without ListTile placeholder rendering.

### Client Portal

- Client login role supported by backend and app.
- Client sees only their own profile data.
- Client portal includes:
  - personal summary;
  - visits/spend/reward stats;
  - upcoming bookings;
  - booking history;
  - own visual photo history with fullscreen preview;
  - new booking request form.
- Client booking request:
  - choose service;
  - choose employee;
  - choose zone when needed;
  - choose available time;
  - add comment.
- Backend forces client bookings to the authenticated client and creates them as pending requests.

## Backend API Used

- `GET/PATCH /api/v1/me/`
- `GET/POST /api/v1/clients/`
- `GET/PATCH /api/v1/clients/<id>/`
- `GET/POST /api/v1/employees/`
- `GET/PATCH /api/v1/employees/<id>/`
- `GET/POST /api/v1/services/`
- `GET/PATCH /api/v1/services/<id>/`
- `GET/POST /api/v1/zones/`
- `GET/PATCH /api/v1/zones/<id>/`
- `GET/POST /api/v1/bookings/`
- `GET/PATCH /api/v1/bookings/<id>/`
- `POST /api/v1/bookings/<id>/reschedule/`
- `POST /api/v1/bookings/<id>/status/`
- `GET/POST /api/v1/bookings/<id>/photos/`
- `GET /api/v1/photos/<id>/image/`
- `POST /api/v1/bookings/check-availability/`
- `GET /api/v1/availability/slots/`
- `GET/POST /api/v1/time-blocks/`
- `GET/PATCH/DELETE /api/v1/time-blocks/<id>/`
- `GET /api/v1/calendar/day/`

## Local Setup

```powershell
C:\src\flutter\bin\flutter.bat pub get
C:\src\flutter\bin\flutter.bat run
```

Quality checks:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe format lib
C:\src\flutter\bin\flutter.bat analyze
```

## Deployment Notes

- Backend changes for client portal require migrations:
  - `accounts.0002_user_client_role`
  - `clients.0003_client_user`
- After pulling backend changes on the server, run:

```powershell
python manage.py migrate
```

Then restart the backend service.

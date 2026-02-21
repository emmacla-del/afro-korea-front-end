# Afro-Korea Pool (Flutter App + API)

AfroPool is a dual-supply marketplace concept where customers can browse products sourced from **Nigeria** (faster/cheaper) and **Korea** (premium/unique), and (in the backend) place pooled commitments toward a quantity threshold (MOQ/threshold pooling).

This workspace contains:

- A **Flutter** client (this folder)
- An optional **NestJS + Prisma** API in `server/` (PostgreSQL)

Current state (from code):

- The Flutter UI uses **mock product data** (`lib/services/mock_product_service.dart`) and is **not yet wired** to the API.
- The API implements the pooling/order/catalog MVP and uses header-based "MVP auth" (`x-user-id`).

## Tech stack

**Mobile/Web/Desktop (Flutter)**

- Flutter + Dart (Dart SDK constraint: `>= 3.10.1` from `pubspec.yaml`)
- Material UI
- `flutter_test` + `network_image_mock` for widget tests

**Backend API (optional)**

- Node.js + TypeScript
- NestJS with Fastify adapter (`@nestjs/platform-fastify`)
- Prisma ORM + PostgreSQL
- Zod for request validation
- Scheduled job loop (Nest Schedule) to expire/finalize pools

## Main features

**Flutter app (MVP UI)**

- Role switching: Customer vs Supplier (`lib/main.dart` + `lib/widgets/role_switch_action.dart`)
- Customer home screen: supplier-origin filter, category chips, search, product grid, MOQ progress (`lib/pages/home_page.dart`)
- Supplier dashboard placeholder (`lib/pages/supplier_dashboard_page.dart`)

**API (MVP)**

- Public product browse: `GET /products`
- Supplier catalog: create products/variants + bulk import (`/supplier/*` endpoints)
- Pooling:
  - Create pool: `POST /pools`
  - Commit to pool: `POST /pools/:id/commit` (requires `x-user-id`)
  - View pool: `GET /pools/:id`
- Orders:
  - Direct order: `POST /orders/direct` (requires `x-user-id`)
  - List my orders: `GET /me/orders` (requires `x-user-id`)
  - Get order: `GET /orders/:id` (requires `x-user-id`)
- Supplier purchase orders: list/confirm/ship (`/supplier/purchase-orders/*`)
- Health check: `GET /health`
- DEV-only endpoints protected by `x-admin-secret` (see env vars below)

## Folder structure

```
.
|-- lib/                  # Flutter source
|   |-- app/              # app-level types (roles, etc.)
|   |-- models/           # data models (e.g. Product)
|   |-- pages/            # screens (home, supplier dashboard)
|   |-- services/         # data access (currently mock)
|   `-- widgets/          # reusable UI components
|-- test/                 # Flutter tests
|-- android/ ios/         # Flutter platform targets
|-- windows/ macos/ linux/ # Flutter desktop targets
|-- web/                  # Flutter web target
`-- server/               # Optional NestJS/Prisma API
    |-- src/              # controllers/services/modules
    `-- prisma/           # schema + migrations
```

## Installation & setup

### 1) Flutter app

From this directory:

```bash
flutter pub get
```

Verify your environment:

```bash
flutter doctor -v
```

### 2) Backend API (optional)

Prereqs: Node.js + a PostgreSQL database.

From `server/`:

```bash
copy .env.example .env
npm install
npm run prisma:generate
npm run prisma:migrate
```

If you are on Windows PowerShell and `npm` fails due to script execution policy, use `npm.cmd` instead (for example `npm.cmd install`).

## Configuration / environment variables

### API (`server/.env`)

`server/.env.example` defines:

| Variable | Required | Description | Example |
| --- | --- | --- | --- |
| `PORT` | No | HTTP port the API listens on | `3000` |
| `DATABASE_URL` | Yes | PostgreSQL connection string used by Prisma | `postgresql://...` |
| `JOB_WORKER_ENABLED` | No | Enables the pool scheduler loop (`true`/`false`) | `true` |
| `DEV_ADMIN_SECRET` | Yes (for DEV endpoints) | Enables/protects DEV-only endpoints via `x-admin-secret` | `change-me` |

Auth model (MVP):

- Most non-public endpoints require `x-user-id: <uuid>`.
- DEV endpoints require `x-admin-secret: <DEV_ADMIN_SECRET>`.

## How to run

### Run the Flutter app (hot reload)

List available targets:

```bash
flutter devices
```

Run (Windows desktop):

```bash
flutter run -d windows
```

Alternatives:

- Web: `flutter run -d chrome`
- Android: `flutter run -d <device-id>`

### Run the API (optional)

From `server/`:

```bash
npm run dev
```

The API listens on `https://afro-korea-pool-server.onrender.com` in production (or on localhost when running locally).

## Usage examples (API)

Health check:

```bash
curl https://afro-korea-pool-server.onrender.com/health
```

List public products:

```bash
curl https://afro-korea-pool-server.onrender.com/products
```

Create a pool (replace UUIDs):

```bash
curl -X POST https://afro-korea-pool-server.onrender.com/pools \
  -H "content-type: application/json" \
  -d '{"variantId":"00000000-0000-0000-0000-000000000000","deadlineAt":"2026-02-06T12:00:00.000Z"}'
```

Commit to a pool (requires MVP auth header):

```bash
curl -X POST https://afro-korea-pool-server.onrender.com/pools/<pool-id>/commit \
  -H "content-type: application/json" \
  -H "x-user-id: 00000000-0000-0000-0000-000000000000" \
  -d '{"qty":10}'
```

For more API details and the MVP flows, see `server/README.md`.

## Quality checks

Flutter:

```bash
flutter analyze
flutter test
```

API (build):

```bash
cd server
npm run build
```

## Future improvements (from current gaps)

- Wire the Flutter UI to the API (replace `MockProductService` with real HTTP calls).
- Add real authentication/authorization (replace header-based MVP auth).
- Integrate real payment providers and webhook handling (API currently has DEV-only "mark paid").
- Add API tests and CI coverage for core pooling flows.
- Add a root-level `LICENSE` file if this project is intended to be open source.

## License

No workspace-level `LICENSE` file is present.

- The backend package declares `ISC` in `server/package.json`.

If you plan to distribute this repository, add an explicit `LICENSE` file at the root.

## More docs

- Dev runbook: `docs/DEVELOPMENT.md`
- App overview: `docs/APP_OVERVIEW.md`

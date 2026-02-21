# App overview (MVP)

## Concept

AfroPool is a dual-supply marketplace concept:

- **Nigeria supply**: faster shipping, cheaper pricing
- **Korea supply**: premium/unique items, longer shipping, customs

The key feature is **pooling (MOQ/threshold)**:
- Customers "join" a pool for a product variant.
- The pool progresses toward a threshold quantity.
- When the threshold is met, payment and supplier purchase order flows can begin (backend supports this concept).

## Roles

The Flutter app currently supports two modes:

- **Customer**: browse products and join pools
- **Supplier**: placeholder dashboard for catalog/order management

Switch roles:
- App bar action (pill button) via `lib/widgets/role_switch_action.dart`
- Banner button on supplier dashboard via `lib/widgets/role_mode_banner.dart`

## Screens

### Customer home

File: `lib/pages/home_page.dart`

Current UI includes:
- Supplier-origin filter (All / Nigeria / Korea)
- Category chips (All, Beauty, Fashion, Electronics, Home, Food)
- Search field (filters by product title)
- Product grid with MOQ progress and shipping estimate

Actions:
- "Join Pool" / "Buy Now" are currently **stubbed** (they show a SnackBar).

### Supplier dashboard

File: `lib/pages/supplier_dashboard_page.dart`

This is a **placeholder** screen showing cards for:
- Products
- Purchase Orders
- Catalog Import

No backend wiring yet in the Flutter UI.

## Data and models

- Product model: `lib/models/product.dart`
- Current data source: `lib/services/mock_product_service.dart` (mock products + placeholder images)

## Backend alignment (optional)

The Node backend in `server/` implements pools/commitments/orders and a supplier catalog API.

Suggested next step for wiring Flutter -> backend:
- Replace `MockProductService` with an API service in `lib/services/` that calls `server/` endpoints.
- Introduce a single base URL configuration (for example via `--dart-define`), and keep mock data as a fallback for offline/demo mode.

Backend docs: `server/README.md`

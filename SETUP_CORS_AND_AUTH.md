# Setup Guide: CORS & x-user-id Authentication

This guide explains how to fix "Failed to fetch" errors when calling `/supplier/products` and other protected endpoints.

## Problem Summary

1. **Backend CORS disabled in production** — `server/src/main.ts` sets `origin: false` when `NODE_ENV === 'production'`
2. **Frontend missing `x-user-id` header** — Supplier endpoints require valid UUID in `x-user-id` header
3. **Deployed service may not be reachable** — Test connectivity first before debugging auth

---

## Solution Overview

### Backend Changes (Already Applied)

**File:** `server/src/main.ts`

CORS now reads `CORS_ORIGIN` environment variable:

```typescript
await app.register(fastifyCors, {
  origin: (() => {
    const raw = process.env.CORS_ORIGIN?.trim();
    if (raw && raw.length > 0) {
      // Support '*' (allow all), or a comma-separated list of origins
      if (raw === '*') return true;
      return raw.split(',').map((s) => s.trim());
    }
    // Default: allow all on non-production, disable by default in production
    return process.env.NODE_ENV === 'production' ? false : true;
  })(),
  credentials: true,
});
```

**Behavior:**

- If `CORS_ORIGIN=*` → Allow all origins (permissive, for testing only)
- If `CORS_ORIGIN=https://your-app.vercel.app,https://your-app.netlify.com` → Allow specified origins
- If unset → Allow all origins on non-production; deny all on production

### Frontend Changes (Already Applied)

#### 1. User ID Persistent Storage

**File:** `lib/services/user_store.dart` (NEW)

```dart
class UserStore {
  // Save supplier/customer UUID for later use
  static Future<void> saveUserId(String userId) async { ... }
  
  // Retrieve saved user ID
  static Future<String?> getUserId() async { ... }
  
  // Clear stored user ID
  static Future<void> clear() async { ... }
}
```

#### 2. API Client with x-user-id Support

**File:** `lib/api/api_client.dart` (UPDATED)

Added `userIdProvider` parameter:

```dart
class ApiClient {
  final UserIdProvider? userIdProvider;
  
  ApiClient({
    http.Client? httpClient,
    JwtTokenProvider? tokenProvider,
    this.userIdProvider,  // ← NEW
  }) { ... }
  
  Future<Map<String, String>> _buildHeaders({...}) async {
    // ...
    final userId = userIdProvider == null ? null : await userIdProvider!();
    
    return <String, String>{
      // ... other headers
      if (userId != null && userId.isNotEmpty) 'x-user-id': userId,
    };
  }
}
```

#### 3. Supplier API with Auto User ID

**File:** `lib/api/supplier_api.dart` (UPDATED)

Now automatically includes user ID from storage:

```dart
SupplierApi({ApiClient? client}) 
  : _client = client ?? ApiClient(
      userIdProvider: () => UserStore.getUserId(),
    );
```

---

## Step-by-Step: Configure Render

### 1. Get Your Render Dashboard Link

1. Go to [https://dashboard.render.com](https://dashboard.render.com)
2. Sign in with your account
3. Find your NestJS backend service (e.g., "afropool-backend")

### 2. Set CORS_ORIGIN Environment Variable

1. **Click the service name** to open settings
2. **Navigate to "Environment"** tab (or "Settings" → "Environment")
3. **Click "Add Environment Variable"**
4. **Set key:** `CORS_ORIGIN`
5. **Set value** (choose one):

   - **For local testing (allow all):**
     ```
     *
     ```

   - **For production (specific origin):**
     ```
     https://your-frontend-domain.com
     ```

   - **For multiple origins:**
     ```
     https://your-app.vercel.app,https://your-app.netlify.app
     ```

   - **For local + production:**
     ```
     http://localhost:3000,http://localhost:8080,https://your-frontend-domain.com
     ```

6. **Click "Save"** → Render will redeploy your service automatically

7. **Wait for deployment** — Watch the logs to confirm the service restarted

### 3. Verify the Variable was Set

After deployment, check logs:

```bash
curl https://afro-korea-pool-server.onrender.com/health
```

If you see `{ "ok": true }`, CORS is now enabled (and the service is responding).

---

## Step-by-Step: Set User ID in Flutter

### 1. Import UserStore in Your Code

```dart
import 'package:mobile/services/user_store.dart';
import 'package:mobile/api/supplier_api.dart';

// In a supplier login or initialization flow:
Future<void> loginSupplier(String supplierUuid) async {
  // Save the supplier's user ID
  await UserStore.saveUserId(supplierUuid);
  
  // Now all SupplierApi calls will include x-user-id header automatically
  final api = SupplierApi();
  final products = await api.getSupplierProducts(page: 1, pageSize: 10);
  print('Products: $products');
}
```

### 2. Test in Your App

Once `UserStore.saveUserId()` is called with a valid supplier UUID:

- All subsequent API calls via `SupplierApi` will automatically include `x-user-id` header
- Requests to `/supplier/products`, `/supplier/purchase-orders`, etc. will succeed (if the server is running)

### 3. Retrieve Stored User ID (for debugging)

```dart
final userId = await UserStore.getUserId();
print('Current user: $userId');
```

### 4. Clear User ID (logout)

```dart
await UserStore.clear();
```

---

## Testing: Verify Service is Running

### Test 1: Check Health Endpoint (No Auth Required)

```bash
curl -v https://afro-korea-pool-server.onrender.com/health
```

**Expected response:**
```
HTTP/2 200
{ "ok": true }
```

**If you get 404 or "Connection refused":**
- Service is down or deployment failed
- Check Render logs: Dashboard → Service → Logs tab

### Test 2: Check Public Products (No Auth Required)

```bash
curl -v https://afro-korea-pool-server.onrender.com/products
```

**Expected response:**
```
HTTP/2 200
[...array of products...]
```

### Test 3: Check Supplier Products (Requires x-user-id)

Replace `<SUPPLIER_UUID>` with a valid supplier UUID from your database:

```bash
curl -v \
  -H "x-user-id: <SUPPLIER_UUID>" \
  https://afro-korea-pool-server.onrender.com/supplier/products
```

**If you get a valid supplier UUID:**
- HTTP/2 200 with product list

**If you don't have a supplier UUID, create one via dev endpoint:**

```bash
curl -X POST https://afro-korea-pool-server.onrender.com/dev/seed/supplier \
  -H "Content-Type: application/json" \
  -H "x-admin-secret: <YOUR_DEV_ADMIN_SECRET>" \
  -d '{"displayName":"Test Supplier"}'
```

Replace `<YOUR_DEV_ADMIN_SECRET>` with the value from your `.env` file (`DEV_ADMIN_SECRET`).

**Response example:**
```json
{
  "supplierUserId": "550e8400-e29b-41d4-a716-446655440000",
  "supplierId": "550e8400-e29b-41d4-a716-446655440001"
}
```

### Test 4: Verify CORS is Enabled

Send a request **from a browser** (or use curl with `Origin` header):

```bash
curl -v \
  -H "Origin: https://your-frontend-domain.com" \
  -H "x-user-id: <SUPPLIER_UUID>" \
  https://afro-korea-pool-server.onrender.com/supplier/products
```

**Expected response headers (if CORS enabled):**
```
Access-Control-Allow-Origin: https://your-frontend-domain.com
Access-Control-Allow-Credentials: true
```

**If you see these headers, CORS is working.**

---

## Troubleshooting

### "Failed to fetch" in Browser

1. **Check CORS_ORIGIN is set** — Go to Render Dashboard → Environment tab
2. **Check service is running** — `curl https://afro-korea-pool-server.onrender.com/health`
3. **Check x-user-id header is sent** — Open DevTools → Network tab, look for `x-user-id` in request headers
4. **Check UserStore.getUserId() returns non-empty value** — Add debug print or logging

### 401/400 on /supplier/products

1. **x-user-id header missing** — Ensure `UserStore.saveUserId()` was called before API request
2. **Invalid UUID format** — UUID must be valid v4 format (8-4-4-4-12 hex digits)
3. **Supplier doesn't exist** — Create test supplier via `/dev/seed/supplier` endpoint

### Service Returns 404

1. **Check Render service is deployed** — Dashboard → Logs tab should show "Server running"
2. **Check environment is 'production'** — Render sets `NODE_ENV=production` automatically
3. **Redeploy manually** — Dashboard → service → Manual Deploy

### Still Failing After These Steps

Collect debugging info:

```bash
# 1. Check service status
curl -v https://afro-korea-pool-server.onrender.com/health

# 2. Check CORS headers
curl -v -H "Origin: http://localhost:3000" https://afro-korea-pool-server.onrender.com/health

# 3. Check with user ID
curl -v \
  -H "x-user-id: 550e8400-e29b-41d4-a716-446655440000" \
  https://afro-korea-pool-server.onrender.com/supplier/products

# 4. Check Render logs for errors
# Go to: https://dashboard.render.com → service → Logs tab
```

Share the output of these commands for further debugging.

---

## Summary

| Component | Change | File |
|-----------|--------|------|
| Backend CORS | Reads `CORS_ORIGIN` env var | `server/src/main.ts` |
| Frontend User ID Storage | New persistent storage using SharedPreferences | `lib/services/user_store.dart` |
| API Client | Auto-includes `x-user-id` header when provided | `lib/api/api_client.dart` |
| Supplier API | Auto-wires UserStore for user ID | `lib/api/supplier_api.dart` |

**Next steps:**

1. ✅ **Backend:** Set `CORS_ORIGIN` in Render environment variables
2. ✅ **Frontend:** Call `UserStore.saveUserId('<uuid>')` before making API calls
3. ✅ **Test:** Use curl commands above to verify service is responding
4. ✅ **Debug:** Check browser DevTools Network tab for x-user-id header

---

## Environment Variables Reference

### Server (.env or Render)

| Variable | Example | Purpose |
|----------|---------|---------|
| `PORT` | `3000` | Server port (Render default: 3000) |
| `HOST` | `0.0.0.0` | Listen on all interfaces (required for Render) |
| `NODE_ENV` | `production` | Render sets this automatically |
| `DATABASE_URL` | `postgresql://...` | PostgreSQL connection (Prisma) |
| `CORS_ORIGIN` | `*` or `https://domain.com` | **NEW:** Allow frontend origin |
| `DEV_ADMIN_SECRET` | `change-me` | Secret for `/dev/*` endpoints |
| `JOB_WORKER_ENABLED` | `true` | Enable pool scheduler job |

---

## Quick Reference: Full Integration Example

```dart
// 1. On app startup or after supplier login:
import 'package:mobile/services/user_store.dart';

await UserStore.saveUserId('550e8400-e29b-41d4-a716-446655440000');

// 2. Use SupplierApi - it auto-includes x-user-id now:
import 'package:mobile/api/supplier_api.dart';

final api = SupplierApi();
try {
  final summary = await api.getProductSummary();
  print('Product summary: ${summary.total} total, ${summary.openPool} open pools');
} catch (e) {
  print('Error: $e');
  // Check browser DevTools → Network tab for error details
}
```

---

**Questions?** Check the troubleshooting section or the backend server logs on Render.

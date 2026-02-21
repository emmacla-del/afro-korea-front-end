# Comprehensive Code Review: Afro-Korea Pool Full Stack

**Date:** February 11, 2026  
**Reviewed:** Flutter Frontend + NestJS Backend  
**Severity Classification:** 🔴 Critical | 🟠 High | 🟡 Medium | 🟢 Low

---

## PART 1: FRONTEND (FLUTTER) ISSUES

### 1. 🔴 CRITICAL: Multiple Product Model Definitions Causing Type Mismatch

**Files:**
- `lib/models/product.dart` (PRIMARY - used by ProductCard, UI)
- `lib/models/product_model.dart` (NEW - created for ApiService, uses `intl`)
- `lib/models/supplier_product.dart` (SECONDARY - supplier-specific)

**Problem:**
The codebase has competing `Product` implementations:

```dart
// EXISTING: product.dart
class Product {
  final String id;
  final String title;
  final String supplierOrigin; // 'nigeria' or 'korea'
  final int moq; // minimum order quantity
  final int currentOrders;
  final PoolSummary? poolSummary;
  // ... 12 more fields
}

// NEW: product_model.dart
class Product {
  final String id;
  final String name;  // ❌ MISMATCH: was 'title'
  final double price; // ❌ MISMATCH: was 'priceXaf'
  final String currency;
  // No supplierOrigin, no poolSummary, no moq, etc.
}
```

**Impact:**
- **RUNTIME CRASH:** When `ApiService.fetchProducts()` returns `Product` from Dio and passes it to `ProductCard` (which expects legacy model), the widget will fail: `NoSuchMethodError: No such method 'moq' on Product`
- Duplicate type definitions confuse developers
- Type-unsafe deserialization path

**Why It Happened:**
- Legacy UI built against mock data with specific schema
- New API integration layer created with minimal Product model
- No schema alignment before creating new types

**Fix:** MERGE both models into ONE authoritative `Product` class

```dart
// lib/models/product.dart - UNIFIED MODEL
import 'package:intl/intl.dart';

class Product {
  // === IDs & Metadata ===
  final String id;
  final String title;
  final String? description;
  final String category;
  final bool isActive;
  
  // === Pricing ===
  final double priceXaf;
  final String currency;
  
  // === Supply Market Info ===
  final String supplierOrigin; // 'nigeria' | 'korea'
  final String supplierId;
  final String supplierName;
  final String supplierCity;
  
  // === MOQ Pooling ===
  final int moq;
  final int currentOrders;
  final DateTime poolingDeadline;
  final PoolSummary? poolSummary;
  
  // === Logistics ===
  final int estimatedDays;
  final bool requiresCustoms;
  final List<String> images;
  
  // === Timestamps ===
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    required this.isActive,
    required this.priceXaf,
    required this.currency,
    required this.supplierOrigin,
    required this.supplierId,
    required this.supplierName,
    required this.supplierCity,
    required this.moq,
    required this.currentOrders,
    required this.poolingDeadline,
    this.poolSummary,
    required this.estimatedDays,
    required this.requiresCustoms,
    required this.images,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Deserialize from backend Prisma response
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      category: json['category'] as String? ?? 'Other',
      isActive: json['isActive'] as bool? ?? true,
      priceXaf: _parseDouble(json['unitPriceXaf'] ?? json['price']),
      currency: json['currency'] as String? ?? 'XAF',
      supplierOrigin: (json['supplier']?['displayName'] as String? ?? 'unknown').toLowerCase().contains('korea') ? 'korea' : 'nigeria',
      supplierId: json['supplierId'] as String? ?? '',
      supplierName: json['supplier']?['displayName'] as String? ?? 'Unknown',
      supplierCity: json['supplier']?['city'] as String? ?? '',
      moq: json['thresholdQty'] as int? ?? 0,
      currentOrders: json['committedQty'] as int? ?? 0,
      poolingDeadline: _parseDateTime(json['deadlineAt'] ?? DateTime.now().add(Duration(days: 7))),
      poolSummary: null, // Will be hydrated from parent context
      estimatedDays: json['leadTimeDays'] as int? ?? 14,
      requiresCustoms: (json['supplier']?['displayName'] as String? ?? '').toLowerCase().contains('korea'),
      images: _parseImages(json),
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {}
    }
    return DateTime.now();
  }

  static List<String> _parseImages(Map<String, dynamic> json) {
    if (json['images'] is List) {
      return List<String>.from(json['images'] as List);
    }
    return [];
  }

  /// Format price with XAF currency
  String get formattedPrice {
    return '${priceXaf.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    )} XAF';
  }

  /// Progress: 0.0 to 1.0
  double get poolProgress => moq == 0 ? 0.0 : (currentOrders / moq).clamp(0.0, 1.0);

  /// Readable deadline string
  String get deadlineReadable {
    final formatter = DateFormat('MMM d, yyyy');
    return formatter.format(poolingDeadline);
  }
}
```

**Then delete:**
- `lib/models/product_model.dart` (entire file)

**Update `lib/services/api_service.dart`:**
```dart
// Change import
// FROM: import '../models/product_model.dart';
// TO:
import '../models/product.dart';

// Change return type
Future<List<Product>> fetchProducts() async {
  // ... existing code returns List<Product>
}
```

**Why:** Single source of truth eliminates Dart type errors and runtime crashes.

---

### 2. 🔴 CRITICAL: Duplicate HTTP Clients - No Clear API Integration Path

**Files:**
- `lib/services/api_client.dart` (legacy, uses `http` package, hardcoded `localhost:3000`)
- `lib/services/api_service.dart` (production Dio, Render URL, interceptors)
- `lib/api/api_client.dart` (yet another copy with hardcoded localhost)

**Problem:**
```dart
// api_client.dart (legacy)
class ApiClient {
  static const String baseUrl = 'https://afropool-backend.onrender.com'; // production URL
}

// services/api_client.dart (SAME NAME - different package!)
class ApiClient {
  Uri baseUri; // Platform-aware but confusing
}

// services/api_service.dart (NEW, production-ready)
class ApiService {
  static const String _baseUrl = 'https://afro-korea-pool-server.onrender.com';
}
```

**Impact:**
- Two `ApiClient` classes in different packages = confusing imports
- UI code may import wrong one, leading to localhost-only access
- Bearer token support only in `ApiService`, not `api_client.dart`
- No clear migration path for UI to use production client

**Evidence from code:**
```dart
// lib/api/supplier_api.dart
class SupplierApi {
  final ApiClient _client; // ❌ Which ApiClient? lib/api or lib/services?
  
  SupplierApi({ApiClient? client}) : _client = client ?? ApiClient(); // AMBIGUOUS
}

// lib/pages/supplier_product_create_page.dart
import '../api/api_client.dart'; // ❌ Imports WRONG api_client (localhost)
final SupplierApi _api = SupplierApi(); // Uses hardcoded localhost
```

**Fix:**

1. **Delete** `lib/api/api_client.dart` entirely (redundant copy)

2. **Standardize** `lib/services/api_client.dart` as the PRIMARY client (rename to clarify):
   ```dart
   // lib/services/http_client.dart (rename, not api_client)
   class HttpClient {
     Uri baseUri; // Stays platform-aware
     // Existing implementation
   }
   ```

3. **Deprecate** `lib/services/api_service.dart` OR make it wrap HttpClient:
   ```dart
   // lib/services/api_service.dart - SINGLE SOURCE OF TRUTH
   import 'http_client.dart';
   
   class ApiService {
     static final ApiService _instance = ApiService._internal();
     late final HttpClient _httpClient;
     String? _bearerToken;
     
     ApiService._internal() {
       _httpClient = HttpClient();
     }
     
     static ApiService get instance => _instance;
     
     Future<List<Product>> fetchProducts() async {
       final json = await _httpClient.get('/products');
       // Parse response
     }
   }
   ```

4. **Update all imports** to use single source:
   ```dart
   // BEFORE (scattered)
   import '../api/api_client.dart';
   import '../services/api_client.dart';
   import '../services/api_service.dart';
   
   // AFTER (unified)
   import '../services/api_service.dart';
   final api = ApiService.instance;
   ```

**Why:** One HTTP client = one code path = predictable behavior.

---

### 3. 🟠 HIGH: Widget Constructor Signature Mismatches

**File:** `lib/main.dart`, `lib/pages/home_page.dart`, `lib/widgets/product_card.dart`

**Problem:**
```dart
// lib/main.dart (line 42)
home: _role == AppRole.customer
  ? HomePage(currentRole: _role, onRoleChanged: _setRole) // ❌ UNKNOWN PARAMS
  : SupplierDashboardPage(currentRole: _role, onRoleChanged: _setRole),

// But HomePage doesn't accept these:
class HomePage extends StatefulWidget {
  const HomePage({super.key}); // ❌ NO currentRole, onRoleChanged
}

// lib/pages/home_page.dart (line 252)
return ProductCard(
  // ... other args
  // ❌ MISSING: onJoinPool and onBuyNow
);

// lib/widgets/product_card.dart
class ProductCard extends StatelessWidget {
  final VoidCallback onJoinPool;
  final VoidCallback onBuyNow;
  // ❌ These are REQUIRED but HomePage doesn't provide
}
```

**Fix:**

**Option A (Recommended): Remove role-switching from HomePage**
```dart
// lib/pages/home_page.dart
class HomePage extends StatefulWidget {
  const HomePage({super.key}); // Remove currentRole, onRoleChanged

// lib/main.dart
home: _role == AppRole.customer ? const HomePage() : const SupplierDashboardPage(),

// For role switching, use a separate button in app bar or settings page
```

**Option B: Add role parameters to HomePage**
```dart
class HomePage extends StatefulWidget {
  final AppRole currentRole;
  final Function(AppRole) onRoleChanged;
  
  const HomePage({
    super.key,
    required this.currentRole,
    required this.onRoleChanged,
  });
}
```

**For ProductCard callbacks:**
```dart
// lib/pages/home_page.dart - Add callbacks when building ProductCard
return ProductCard(
  product: product,
  onTap: () => _showProductDetail(product),
  onLongPress: () {},
  onJoinPool: () {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Joining pool...')),
    );
    _joinPool(product);
  },
  onBuyNow: () {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Buy now redirect...')),
    );
    _buyNow(product);
  },
);
```

---

### 4. 🟡 MEDIUM: Missing `intl` Package Dependency

**File:** `pubspec.yaml`

**Problem:**
```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.5.0
  dio: ^5.4.0
  # ❌ MISSING: intl
```

But `lib/models/product_model.dart` imports:
```dart
import 'package:intl/intl.dart'; // ❌ BREAKS if intl not in pubspec
```

**Fix:** Add to `pubspec.yaml`:
```yaml
dependencies:
  # ... existing
  intl: ^0.19.0
```

Then run:
```bash
flutter pub get
```

---

### 5. 🟠 HIGH: Type Safety Issues in Api Responses

**Files:** `lib/services/api_client.dart`, `lib/api/supplier_api.dart`, `lib/services/pool_service.dart`

**Problem:**
```dart
// lib/api/supplier_api.dart
Future<SupplierProductSummary> getProductSummary() async {
  final json = await _client.get('/supplier/products/summary');
  if (json is! Map) {
    throw ApiException(
      statusCode: 200,
      reasonPhrase: 'OK', // ❌ ApiException doesn't have 'reasonPhrase'
      body: json?.toString() ?? 'null',
      message: 'Unexpected response for product summary',
    );
  }
}

// lib/services/pool_service.dart
throw ApiException(
  statusCode: 200,
  reasonPhrase: 'OK', // ❌ SAME ERROR
  body: json?.toString() ?? 'null',
  message: 'Unexpected response from commit endpoint',
);
```

**Why:** `ApiException` (defined in `api_client.dart`) doesn't have `reasonPhrase` or `body` fields:
```dart
class ApiException implements Exception {
  final int? statusCode;
  final String reasonPhrase; // ❌ DOESN'T EXIST
  final String body;         // ❌ DOESN'T EXIST
}
```

**Fix:** Use correct fields or add them:
```dart
// Option 1: Use correct fields
throw ApiException(
  statusCode: 200,
  message: 'Unexpected response type: expected Map, got ${json.runtimeType}',
);

// Option 2: Extend ApiException (BETTER)
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic originalError;
  final StackTrace? stackTrace;
  final String? reasonPhrase; // ADD THIS
  final String? body;         // ADD THIS

  ApiException({
    required this.message,
    this.statusCode,
    this.originalError,
    this.stackTrace,
    this.reasonPhrase,
    this.body,
  });
}
```

---

### 6. 🟡 MEDIUM: No Error Handling in Home Page

**File:** `lib/pages/home_page.dart`

**Problem:**
```dart
void _loadProducts() {
  _allProducts = MockProductService.getMockProducts(); // ✅ Works, it's mock
  _filterProducts();
}
```

When switching to real API:
```dart
void _loadProducts() async {
  try {
    _allProducts = await ProductService().listProducts(); // ✅ OK
  } catch (e) {
    // ❌ NO ERROR HANDLING - Widget doesn't show error state
    // User sees nothing or stale data
  }
}
```

**Impact:**
- Network failures silently fail
- No retry mechanism
- No loading state
- UI doesn't inform user of failure

**Fix:**
```dart
class _HomePageState extends State<HomePage> {
  bool _isLoading = false;
  String? _error;

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _allProducts = await ProductService().listProducts();
      _filterProducts();
    } catch (e) {
      setState(() {
        _error = 'Failed to load products: ${e.toString()}';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_error!), duration: Duration(seconds: 5)),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProducts,
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }
    // ... existing build code
  }
}
```

---

### 7. 🟡 MEDIUM: No Bearer Token Support in Legacy ApiClient

**File:** `lib/services/api_client.dart`

**Problem:**
```dart
class ApiClient {
  final JwtTokenProvider tokenProvider;

  Future<Map<String, String>> _buildHeaders({Map<String, String>? extra}) async {
    final token = await tokenProvider();
    return <String, String>{
      'accept': 'application/json',
      'content-type': 'application/json; charset=utf-8',
      'Authorization': 'Bearer ${token ?? ''}', // ❌ Injects EMPTY token!
      ...?extra,
    };
  }
}
```

**Issue:** When `tokenProvider()` returns null, header becomes `'Authorization': 'Bearer '` (invalid).

**Fix:**
```dart
Future<Map<String, String>> _buildHeaders({Map<String, String>? extra}) async {
  final token = await tokenProvider();
  final headers = <String, String>{
    'accept': 'application/json',
    'content-type': 'application/json; charset=utf-8',
    ...?extra,
  };
  
  if (token != null && token.isNotEmpty) {
    headers['Authorization'] = 'Bearer $token';
  }
  
  return headers;
}
```

---

### 8. 🟡 MEDIUM: Misleading Example Code

**File:** `lib/widgets/api_example_widget.dart`

**Problem:**
```dart
// Line 62 (inside build)
style: TextStyle(fontSize: 12, color: Colors.blue[900]), // ❌ Compile error
```

`Colors.blue[900]` returns `Color?` (nullable), but `TextStyle.color` expects `Color`.

**Fix:**
```dart
style: TextStyle(fontSize: 12, color: Colors.blue.shade900), // ✅ Non-null
```

---

### 9. 🟢 LOW: Hardcoded Backend URL in ApiClient

**File:** `lib/services/api_client.dart`

**Problem:**
```dart
static const String baseUrl = 'https://afropool-backend.onrender.com'; // production URL or override for dev
```

Will fail on:
- Real devices (no local server)
- Android emulator (needs 10.0.2.2)
- iOS simulator (needs localhost but with correct port config)

**Fix:** Platform-aware URL selection (you already have this in another client, consolidate):
```dart
class ApiClient {
  static Uri getBaseUrl() {
    const prodUrl = 'https://afro-korea-pool-server.onrender.com';
    const fallbackDevUrl = 'https://afropool-backend.onrender.com';

    // Check for environment override
    const String? envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl != null && envUrl.isNotEmpty) {
      return Uri.parse(envUrl);
    }

    // Determine based on platform
    if (kIsWeb) return Uri.parse(prodUrl);

    try {
      if (Platform.isAndroid) return Uri.parse('http://10.0.2.2:3000');
      if (Platform.isIOS) return Uri.parse('https://afropool-backend.onrender.com');
    } catch (_) {}

    return Uri.parse(fallbackDevUrl);
  }

  final Uri baseUri = getBaseUrl();
}
```

---

## PART 2: BACKEND (NESTJS) ISSUES

### 10. 🔴 CRITICAL: MVP Auth is Production-Unsafe

**File:** `server/src/common/auth.ts`

**Problem:**
```typescript
export function requireUserId(req: FastifyRequest): string {
  const headerValue = req.headers['x-user-id'];
  if (!headerValue) {
    throw new UnauthorizedException('Missing x-user-id header (MVP auth)');
  }
  if (Array.isArray(headerValue)) {
    throw new BadRequestException('Invalid x-user-id header');
  }
  return String(headerValue); // ❌ ANY STRING IS VALID!
}
```

**Vulnerability:**
- Any client can send `x-user-id: attacker-uuid-12345` and access THAT user's orders/pools
- No token validation, signature checking, or session verification
- Client-side authentication = trivial to bypass

**Attack scenario:**
```bash
# Attacker discovers legitimate user ID (from public listings)
curl -H "x-user-id: legitimate-user-uuid" \
     https://afro-korea-pool-server.onrender.com/me/orders

# Response: All legitimate user's orders + sensitive data
```

**Fix:** Implement JWT or cryptographic authentication

```typescript
// server/src/auth/jwt.strategy.ts
import { Injectable } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor() {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: process.env.JWT_SECRET,
    });
  }

  validate(payload: any) {
    return { userId: payload.sub, role: payload.role };
  }
}

// server/src/common/auth.ts
import { Injectable, CanActivate, ExecutionContext } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  canActivate(context: ExecutionContext) {
    return super.canActivate(context);
  }
}

// Usage in controllers:
@Post('/pools/:id/commit')
@UseGuards(JwtAuthGuard)
async commit(@Req() req, @Param('id') poolId: string) {
  const userId = req.user.userId; // ✅ Verified by JWT
}
```

**Temporary fix (while migrating):** At minimum, validate UUIDs:
```typescript
export function requireUserId(req: FastifyRequest): string {
  const headerValue = req.headers['x-user-id'];
  if (!headerValue || Array.isArray(headerValue)) {
    throw new UnauthorizedException('Invalid x-user-id header');
  }
  
  const userId = String(headerValue).trim();
  
  // Validate UUID format (v4)
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  if (!uuidRegex.test(userId)) {
    throw new BadRequestException('Invalid user ID format');
  }
  
  return userId;
}
```

---

### 11. 🔴 CRITICAL: No Supplier Ownership Validation

**File:** `server/src/catalog/catalog.service.ts`

**Problem:**
```typescript
async createProduct(userId: string, input: CreateProductDto) {
  // ❌ NO CHECK: Is this user a SUPPLIER?
  // ❌ NO CHECK: If multiple suppliers exist, which one is this user?

  const supplierId = ??? // Where does this come from?
  
  return this.prisma.product.create({
    data: {
      title: input.title,
      supplierId, // ❌ Could be ANY supplier ID
      // ...
    },
  });
}
```

**Attack scenario:**
```bash
curl -X POST https://api.example.com/supplier/products \
  -H "x-user-id: user-123" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Fake Nike Shoes",
    "supplierId": "attacker-corp-uuid" # ❌ Attacker passes arbitrary supplier
  }'
```

Result: Attacker creates products under a DIFFERENT supplier's name.

**Fix:** Validate supplier ownership

```typescript
@Injectable()
export class CatalogService {
  constructor(private readonly prisma: PrismaService) {}

  async createProduct(userId: string, input: CreateProductDto) {
    // 1. Verify user is a supplier
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { supplier: true },
    });

    if (!user || user.role !== 'SUPPLIER' || !user.supplier) {
      throw new ForbiddenException('Only suppliers can create products');
    }

    // 2. Use user's own supplier ID (don't trust client input)
    const supplierId = user.supplier.id;

    // 3. Create product
    return this.prisma.product.create({
      data: {
        title: input.title,
        description: input.description,
        category: input.category,
        supplierId, // ✅ Verified supplier
        isActive: true,
      },
    });
  }

  async createVariant(userId: string, input: CreateVariantDto) {
    // 1. Get supplier
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { supplier: true },
    });
    if (!user?.supplier) {
      throw new ForbiddenException('Only suppliers can create variants');
    }

    // 2. Verify product belongs to THIS supplier
    const product = await this.prisma.product.findUnique({
      where: { id: input.productId },
    });
    if (!product || product.supplierId !== user.supplier.id) {
      throw new ForbiddenException('Cannot modify another supplier\'s product');
    }

    // 3. Create variant
    return this.prisma.productVariant.create({
      data: {
        productId: product.id,
        sku: input.sku,
        unitPriceXaf: input.unitPriceXaf,
        thresholdQty: input.thresholdQty,
        leadTimeDays: input.leadTimeDays ?? 7,
        isActive: true,
      },
    });
  }
}
```

---

### 12. 🟠 HIGH: No Quantity Validation in Pool Commit

**File:** `server/src/pools/pools.service.ts`

**Problem:**
```typescript
async commitToPool(input: { poolId: string; userId: string; qty: number }) {
  if (input.qty < 0) {
    throw new BadRequestException('qty must be >= 0'); // ✅ Good
  }
  // ❌ MISSING: Check qty doesn't exceed thresholdQty
  // ❌ MISSING: Check qty > 0 if committing (can't commit zero)

  const nextCommittedQty = pool.committedQty + input.qty;
  
  // ❌ NO CHECK: if nextCommittedQty > thresholdQty, reject!
  // Currently: Can commit 200 items when MOQ is only 100
}
```

**Impact:**
- Pool can be overcommitted
- Supplier receives more orders than advertised MOQ
- Payment calculations become invalid

**Fix:**
```typescript
async commitToPool(input: { poolId: string; userId: string; qty: number }) {
  const now = new Date();

  return this.prisma.$transaction(async (tx) => {
    await tx.$queryRaw`SELECT "id" FROM "Pool" WHERE "id" = ${input.poolId} FOR UPDATE`;

    const pool = await tx.pool.findUnique({
      where: { id: input.poolId },
      include: { commitments: true, variant: true },
    });
    
    if (!pool) throw new NotFoundException('Pool not found');

    // 1. ✅ Validate qty >= 0
    if (input.qty < 0) {
      throw new BadRequestException('qty must be >= 0');
    }

    // 2. ✅ If qty > 0 AND no existing commitment, must be > 0
    const existing = pool.commitments.find(c => c.userId === input.userId);
    if (input.qty > 0 && !existing && input.qty < 1) {
      throw new BadRequestException('Minimum commitment is 1 item');
    }

    // 3. ✅ Calculate new total
    const previousQty = existing?.status === CommitmentStatus.ACTIVE ? existing.qty : 0;
    const nextCommittedQty = pool.committedQty - previousQty + input.qty;

    // 4. ✅ CRITICAL: Don't allow overcommit
    if (nextCommittedQty > pool.thresholdQtySnapshot) {
      throw new BadRequestException(
        `Cannot commit ${input.qty} items. ` +
        `Pool would have ${nextCommittedQty} items, but threshold is ${pool.thresholdQtySnapshot}. ` +
        `Maximum available: ${pool.thresholdQtySnapshot - pool.committedQty + previousQty}`
      );
    }

    // 5. ✅ Check deadline
    if (pool.deadlineAt.getTime() <= now.getTime()) {
      throw new ConflictException('Pool deadline has passed');
    }

    // 6. Proceed with update
    await tx.commitment.upsert({
      where: { poolId_userId: { poolId: input.poolId, userId: input.userId } },
      create: {
        poolId: input.poolId,
        userId: input.userId,
        qty: input.qty,
        status: input.qty > 0 ? CommitmentStatus.ACTIVE : CommitmentStatus.CANCELED,
      },
      update: {
        qty: input.qty,
        status: input.qty > 0 ? CommitmentStatus.ACTIVE : CommitmentStatus.CANCELED,
      },
    });

    return tx.pool.update({
      where: { id: pool.id },
      data: { committedQty: nextCommittedQty },
    });
  });
}
```

---

### 13. 🟠 HIGH: No Inventory Check Before Creating Direct Orders

**File:** `server/src/orders/orders.service.ts`

**Problem:**
```typescript
async createDirectOrder(input: { userId: string; variantId: string; qty: number }) {
  if (input.qty <= 0) throw new BadRequestException('qty must be > 0');

  const variant = await this.prisma.productVariant.findUnique({
    where: { id: input.variantId },
    include: { product: true },
  });
  if (!variant) throw new NotFoundException('Variant not found');

  // ❌ MISSING: Check if supplier has stock
  // ❌ MISSING: Decrement inventory
  // ❌ MISSING: Check for overselling
  
  const amountXaf = variant.unitPriceXaf * input.qty;

  return this.prisma.order.create({
    data: {
      userId: input.userId,
      supplierId: variant.product.supplierId,
      variantId: variant.id,
      qty: input.qty,
      unitPriceXaf: variant.unitPriceXaf,
      amountXaf,
    },
  });
}
```

**Impact:**
- Unlimited orders created against single product
- No backpressure on supplier stock
- Supplier receives 1000s of orders they can't fulfill

**Fix:** Add inventory tracking (requires Prisma schema change + migration):

```typescript
// Assuming you add 'stock' field to ProductVariant model:
// model ProductVariant {
//   ...existing fields...
//   stock: Int @default(0) // Track available inventory
// }

async createDirectOrder(input: { userId: string; variantId: string; qty: number }) {
  if (input.qty <= 0) throw new BadRequestException('qty must be > 0');

  return this.prisma.$transaction(async (tx) => {
    // 1. Lock variant for update
    await tx.$queryRaw`
      SELECT "id" FROM "ProductVariant" 
      WHERE "id" = ${input.variantId} 
      FOR UPDATE
    `;

    const variant = await tx.productVariant.findUnique({
      where: { id: input.variantId },
      include: { product: true },
    });
    
    if (!variant) throw new NotFoundException('Variant not found');
    if (!variant.isActive) throw new BadRequestException('Variant is inactive');

    // 2. Check stock
    if (variant.stock < input.qty) {
      throw new BadRequestException(
        `Insufficient stock. Available: ${variant.stock}, Requested: ${input.qty}`
      );
    }

    // 3. Decrement stock
    await tx.productVariant.update({
      where: { id: variant.id },
      data: { stock: variant.stock - input.qty },
    });

    // 4. Create order
    return tx.order.create({
      data: {
        userId: input.userId,
        supplierId: variant.product.supplierId,
        variantId: variant.id,
        qty: input.qty,
        unitPriceXaf: variant.unitPriceXaf,
        amountXaf: variant.unitPriceXaf * input.qty,
      },
    });
  });
}
```

---

### 14. 🟡 MEDIUM: Missing Input Validation on Pool Deadline

**File:** `server/src/pools/pools.service.ts`

**Problem:**
```typescript
async createPool(input: { variantId: string; deadlineAt: Date }) {
  if (input.deadlineAt.getTime() <= Date.now()) {
    throw new BadRequestException('deadlineAt must be in the future');
  }
  // ❌ MISSING: deadlineAt must be reasonable (not 10 years in future)
  // ❌ MISSING: deadlineAt must be within business hours / timezone aware
}
```

**Attack scenario:**
```bash
curl -X POST /pools \
  -d '{
    "variantId": "uuid",
    "deadlineAt": "2999-12-31T23:59:59Z" # ❌ 973 years in future!
  }'
```

Result: Pool never expires, freezes supplier's inventory.

**Fix:**
```typescript
async createPool(input: { variantId: string; deadlineAt: Date }) {
  const now = new Date();
  const maxDeadline = new Date(now.getTime() + 90 * 24 * 60 * 60 * 1000); // 90 days

  if (input.deadlineAt.getTime() <= now.getTime()) {
    throw new BadRequestException('deadlineAt must be in the future');
  }

  if (input.deadlineAt.getTime() > maxDeadline.getTime()) {
    throw new BadRequestException(
      `deadlineAt cannot exceed 90 days from now. Max: ${maxDeadline.toISOString()}`
    );
  }

  // ... rest of logic
}
```

---

### 15. 🟡 MEDIUM: No Validation on Bulk Import

**File:** `server/src/catalog/catalog.service.ts`

**Problem:**
```typescript
async importCatalog(userId: string, input: ImportCatalogDto) {
  // input.products can have 1000s of items
  // ❌ NO RATE LIMITING
  // ❌ NO SIZE CHECKING
  // ❌ NO DUPLICATE SKU DETECTION
  // ❌ NO OWNERSHIP VALIDATION (reuses createProduct bug #11)

  const products = input.products.map(p => ({
    title: p.title,
    variants: p.variants, // Could be 1000s per product
  }));

  return this.prisma.product.createMany({ data: products }); // ❌ Unbounded
}
```

**Impact:**
- DOS: Attacker imports 10,000 fake products, crashes database
- SKU conflicts: Two products with same SKU
- Supplier impersonation (same as #11)

**Fix:**
```typescript
async importCatalog(userId: string, input: ImportCatalogDto) {
  // 1. Verify user is supplier
  const user = await this.prisma.user.findUnique({
    where: { id: userId },
    include: { supplier: true },
  });
  if (!user?.supplier) {
    throw new ForbiddenException('Only suppliers can import catalogs');
  }

  // 2. Validate bounds
  const MAX_PRODUCTS = 500;
  const MAX_VARIANTS_PER_PRODUCT = 50;
  const MAX_SKU_LENGTH = 80;

  if (input.products.length > MAX_PRODUCTS) {
    throw new BadRequestException(
      `Cannot import more than ${MAX_PRODUCTS} products at once`
    );
  }

  input.products.forEach((p, idx) => {
    if (!p.variants || p.variants.length === 0) {
      throw new BadRequestException(
        `Product at index ${idx} must have at least 1 variant`
      );
    }
    if (p.variants.length > MAX_VARIANTS_PER_PRODUCT) {
      throw new BadRequestException(
        `Product at index ${idx} has ${p.variants.length} variants, max is ${MAX_VARIANTS_PER_PRODUCT}`
      );
    }
    p.variants.forEach((v, vidx) => {
      if (v.sku.length > MAX_SKU_LENGTH) {
        throw new BadRequestException(
          `Product ${idx}, Variant ${vidx}: SKU exceeds ${MAX_SKU_LENGTH} characters`
        );
      }
    });
  });

  // 3. Check for duplicate SKUs within import
  const skus = new Set<string>();
  input.products.forEach(p => {
    p.variants.forEach(v => {
      if (skus.has(v.sku)) {
        throw new BadRequestException(`Duplicate SKU: ${v.sku}`);
      }
      skus.add(v.sku);
    });
  });

  // 4. Check for duplicate SKUs in database
  const existingSkus = await this.prisma.productVariant.findMany({
    where: {
      sku: { in: Array.from(skus) },
      product: { supplierId: user.supplier.id },
    },
    select: { sku: true },
  });

  if (existingSkus.length > 0) {
    throw new ConflictException(
      `SKUs already exist: ${existingSkus.map(s => s.sku).join(', ')}`
    );
  }

  // 5. Perform import within transaction
  return this.prisma.$transaction(async (tx) => {
    const created = [];
    for (const productInput of input.products) {
      const product = await tx.product.create({
        data: {
          title: productInput.title,
          description: productInput.description,
          category: productInput.category,
          supplierId: user.supplier!.id,
          isActive: true,
        },
      });

      const variants = await tx.productVariant.createMany({
        data: productInput.variants.map(v => ({
          productId: product.id,
          sku: v.sku,
          unitPriceXaf: v.unitPriceXaf,
          thresholdQty: v.thresholdQty,
          leadTimeDays: v.leadTimeDays ?? 7,
          isActive: true,
        })),
      });

      created.push({ product, variantsCount: variants.count });
    }
    return created;
  });
}
```

---

### 16. 🟡 MEDIUM: Unprotected DEV Endpoints in Production

**File:** `server/src/dev/dev.controller.ts` (not shown but implied)

**Problem:**
```typescript
@Post('/dev/users')
async createUser(@Body() body: unknown) {
  // ❌ ONLY protected by x-admin-secret header
  // ❌ HEADER CAN BE BYPASSED IN HTTPS without pinning
  // ❌ If deployed to production, these remain accessible
  requireDevAdminSecret(req); // ✅ Good, but insufficient
}

@Post('/dev/seed-supplier')
@Post('/dev/mark-order-paid')
// ... all dev endpoints reachable if x-admin-secret leaks
```

**Fix:**
```typescript
// 1. Only allow in dev mode
@Post('/dev/users')
async createUser(@Req() req: FastifyRequest, @Body() body: unknown) {
  if (process.env.NODE_ENV === 'production') {
    throw new ForbiddenException('DEV endpoints disabled in production');
  }
  
  requireDevAdminSecret(req);
  // ... rest
}

// 2. Or use route guard
@UseGuards(DevModeGuard)
@Post('/dev/users')
async createUser(@Req() req: FastifyRequest, @Body() body: unknown) {
  // ...
}

// server/src/guards/dev-mode.guard.ts
import { Injectable, CanActivate, ExecutionContext, ForbiddenException } from '@nestjs/common';

@Injectable()
export class DevModeGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    if (process.env.NODE_ENV === 'production') {
      throw new ForbiddenException('DEV endpoints disabled in production');
    }
    
    const req = context.switchToHttp().getRequest();
    const expected = process.env.DEV_ADMIN_SECRET;
    const provided = req.headers['x-admin-secret'];
    
    if (!expected || provided !== expected) {
      throw new ForbiddenException('Invalid dev admin secret');
    }
    
    return true;
  }
}
```

---

### 17. 🟠 HIGH: Missing CORS Configuration

**File:** `server/src/main.ts`

**Problem:**
```typescript
const app = await NestFactory.createNestApp(
  AppModule,
  new FastifyAdapter(),
);

// ❌ NO CORS setup visible
await app.register(fastifyCors, {
  origin: process.env.CORS_ORIGIN || '*', // ⚠️ '*' is dangerous!
});
```

**If `CORS_ORIGIN` defaults to `*`:**
- ANY website can make requests to your API
- CSRF attacks possible
- Browser sends credentials with cross-origin requests

**Fix:**
```typescript
const corsOrigin = process.env.CORS_ORIGIN?.split(',').map(o => o.trim()) || [
  'https://afropool-backend.onrender.com',
  'https://afropool-backend.onrender.com',
];

if (process.env.NODE_ENV === 'production') {
  // Whitelist only known production domains
  corsOrigin.length = 0;
  corsOrigin.push('https://afro-korea-pool.cm'); // Your app domain
  corsOrigin.push('https://app.afro-korea-pool.cm');
}

await app.register(fastifyCors, {
  origin: corsOrigin,
  credentials: true,
  methods: ['GET', 'POST', 'PATCH', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization', 'x-user-id'],
});
```

---

### 18. 🟡 MEDIUM: No Logging or Audit Trail

**Files:** All controllers

**Problem:**
```typescript
@Post('/pools/:id/commit')
async commit(@Req() req: FastifyRequest, @Param('id') poolId: string) {
  // When attacker manipulates data, no audit trail exists
  // No logging: Who committed, when, how much, from where
}
```

**Impact:**
- Fraud undetectable
- No forensics after security breach
- Compliance failures (audit requirements)

**Fix:** Add structured logging

```typescript
import { Logger } from '@nestjs/common';

@Injectable()
export class PoolsService {
  private readonly logger = new Logger(PoolsService.name);

  async commitToPool(input: { poolId: string; userId: string; qty: number }, clientIp?: string) {
    this.logger.log(
      `User ${input.userId} committing ${input.qty} items to pool ${input.poolId}`,
      { clientIp, timestamp: new Date().toISOString() }
    );

    try {
      const result = await this.prisma.$transaction(async (tx) => {
        // ... existing logic
      });

      this.logger.log(`Commitment successful for ${input.userId}`);
      return result;
    } catch (error) {
      this.logger.error(
        `Commitment failed for ${input.userId}: ${error.message}`,
        error.stack
      );
      throw error;
    }
  }
}

// In controller:
@Post('/pools/:id/commit')
@UseGuards(JwtAuthGuard)
async commit(@Req() req, @Param('id') poolId: string, @Body() body: unknown) {
  const userId = req.user.userId;
  const clientIp = req.ip || req.headers['x-forwarded-for'];
  
  return this.poolsService.commitToPool({ poolId, userId, qty: body.qty }, clientIp);
}
```

---

### 19. 🟡 MEDIUM: No Rate Limiting

**All endpoints**

**Problem:**
- Brute force attacks on /dev/users with wrong x-admin-secret
- DOS by spamming /products endpoint
- Commit spam on single pool

**Fix:** Add rate limiting middleware

```bash
npm install @nestjs/throttler
```

```typescript
// app.module.ts
import { ThrottlerModule } from '@nestjs/throttler';

@Module({
  imports: [
    ThrottlerModule.forRoot([
      {
        ttl: 60000, // 1 minute
        limit: 100, // 100 requests
      },
    ]),
    // ... other imports
  ],
})
export class AppModule {}

// Decorate endpoints
import { Throttle } from '@nestjs/throttler';

@Throttle({ default: { limit: 10, ttl: 60000 } }) // 10 per minute
@Post('/pools/:id/commit')
async commit(@Req() req, @Param('id') poolId: string) {
  // ...
}

@Throttle({ default: { limit: 5, ttl: 60000 } }) // Stricter: 5 per minute
@Post('/dev/users')
async createUser(@Req() req, @Body() body: unknown) {
  // ...
}
```

---

### 20. 🟢 LOW: Type Safety in Responses

**File:** `server/src/catalog/catalog.service.ts`

**Problem:**
```typescript
async listPublicProducts() {
  const products = await this.prisma.product.findMany({}); // ✅ Typed
  return products.map((p) => ({
    id: p.id,
    variants: vars.map((v) => ({
      // Response structure is loose, could return extra sensitive fields
    })),
  }));
  // ❌ NO TYPE: Return type not explicitly defined
}
```

**Fix:** Define response DTOs

```typescript
// server/src/catalog/dto/product-response.dto.ts
export class VariantResponseDto {
  id: string;
  sku: string;
  unitPriceXaf: number;
  thresholdQty: number;
  leadTimeDays?: number;
}

export class ProductPublicResponseDto {
  id: string;
  title: string;
  description?: string;
  category?: string;
  supplier: {
    id: string;
    displayName: string;
  };
  variants: VariantResponseDto[];
}

// In service:
async listPublicProducts(): Promise<ProductPublicResponseDto[]> {
  // ... logic
  return products.map(p => ({
    id: p.id,
    title: p.title,
    description: p.description,
    category: p.category,
    supplier: { id: p.supplier.id, displayName: p.supplier.displayName },
    variants: vars.map(v => ({
      id: v.id,
      sku: v.sku,
      unitPriceXaf: v.unitPriceXaf,
      thresholdQty: v.thresholdQty,
      leadTimeDays: v.leadTimeDays,
    })),
  }));
}

// In controller:
@Get('/products')
@ApiResponse({ type: ProductPublicResponseDto, isArray: true })
async listPublicProducts(): Promise<ProductPublicResponseDto[]> {
  return this.catalogService.listPublicProducts();
}
```

---

## PART 3: API INTEGRATION MISMATCHES

### 21. 🔴 CRITICAL: Frontend Expects Different Data Structure Than Backend Returns

**Problem:**

Frontend `ProductCard` expects:
```dart
class Product {
  String id;
  String title;
  String supplierOrigin; // 'nigeria' or 'korea'
  double priceXaf;
  int moq;
  int currentOrders;
  PoolSummary? poolSummary;
  List<String> images;
}
```

Backend `/products` returns:
```json
{
  "id": "uuid",
  "title": "Product",
  "supplierId": "uuid",
  "supplier": {
    "id": "uuid",
    "displayName": "Samsung Korea Co"
  },
  "variants": [
    {
      "id": "uuid",
      "sku": "SAM-001",
      "unitPriceXaf": 25000,
      "thresholdQty": 50,
      "leadTimeDays": 14
    }
  ]
  // ❌ NO: supplierOrigin, moq, currentOrders, poolSummary
}
```

**Impact:**
```dart
// Frontend tries to access:
card.product.supplierOrigin // ❌ CRASH: field doesn't exist
card.product.moq            // ❌ CRASH: field doesn't exist
```

**Fix:** Align frontend model to backend response

```dart
// lib/models/product.dart - UPDATED
class Product {
  final String id;
  final String title;
  final String description;
  final String category;
  final bool isActive;
  final double priceXaf; // From variant.unitPriceXaf
  final String currency;
  
  // Supply market info
  final String supplierId;
  final SupplierInfo supplier;
  final List<VariantInfo> variants; // Flatten this into product fields
  
  // Derived from variant
  final int moq; // From variant.thresholdQty
  final int currentOrders; // Query pools for this variant
  final int estimatedDays; // From variant.leadTimeDays
  
  // Market origin (infer from supplier)
  String get supplierOrigin => 
    supplier.displayName.toLowerCase().contains('korea') ? 'korea' : 'nigeria';

  // ... rest of fields
}

class SupplierInfo {
  final String id;
  final String displayName;
}

class VariantInfo {
  final String id;
  final String sku;
  final int unitPriceXaf;
  final int thresholdQty;
  final int leadTimeDays;
}
```

Then in `ApiService`:
```dart
Future<List<Product>> fetchProducts() async {
  final response = await _dio.get('/products');
  final List<dynamic> items = response.data as List<dynamic>;
  
  return items.map((json) {
    final Map<String, dynamic> map = Map.from(json);
    
    // Get first variant for default pricing
    final variant = (map['variants'] as List?)?.first;
    
    return Product(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      category: map['category'],
      isActive: map['isActive'],
      priceXaf: (variant?['unitPriceXaf'] as num?)?.toDouble() ?? 0.0,
      currency: 'XAF',
      supplierId: map['supplierId'],
      supplier: SupplierInfo(
        id: map['supplier']['id'],
        displayName: map['supplier']['displayName'],
      ),
      variants: List<VariantInfo>.from(
        (map['variants'] as List?)?.map((v) => VariantInfo(
          id: v['id'],
          sku: v['sku'],
          unitPriceXaf: v['unitPriceXaf'],
          thresholdQty: v['thresholdQty'],
          leadTimeDays: v['leadTimeDays'] ?? 7,
        )) ?? []
      ),
      moq: (variant?['thresholdQty'] as int?) ?? 0,
      currentOrders: 0, // ❌ NOT PROVIDED BY API - needs separate pool query
      estimatedDays: (variant?['leadTimeDays'] as int?) ?? 14,
      // ... rest
    );
  }).toList();
}
```

**Backend should also return pool status:**

```typescript
// server/src/catalog/catalog.service.ts
async listPublicProducts() {
  const products = await this.prisma.product.findMany({
    where: { isActive: true },
    include: { supplier: true, variants: { where: { isActive: true } } },
  });

  // Get active pools for each variant
  const variantIds = products.flatMap(p => p.variants.map(v => v.id));
  const pools = await this.prisma.pool.findMany({
    where: {
      variantId: { in: variantIds },
      status: 'OPEN',
    },
    select: { id: true, variantId: true, committedQty: true, thresholdQtySnapshot: true },
  });

  const poolsByVariantId = new Map(pools.map(p => [p.variantId, p]));

  return products.map(p => ({
    ...p,
    variants: p.variants.map(v => ({
      ...v,
      activePool: poolsByVariantId.get(v.id) || null,
    })),
  }));
}
```

Then frontend can access:
```dart
final currentOrders = product.variants.first?.activePool?.committedQty ?? 0;
```

---

## PRIORITY FIXES SUMMARY

| # | Severity | Category | Action | Effort |
|---|----------|----------|--------|--------|
| 10 | 🔴 CRITICAL | Security | Implement JWT auth (replace MVP x-user-id) | 4 hrs |
| 11 | 🔴 CRITICAL | Security | Add supplier ownership validation | 2 hrs |
| 1 | 🔴 CRITICAL | Frontend | Merge Product models | 1 hr |
| 21 | 🔴 CRITICAL | Integration | Align frontend/backend data structures | 2 hrs |
| 2 | 🟠 HIGH | Frontend | Consolidate HTTP clients (remove duplicates) | 1.5 hrs |
| 3 | 🟠 HIGH | Frontend | Fix widget constructor mismatches | 1 hr |
| 12 | 🟠 HIGH | Backend | Add pool overcommitment validation | 1 hr |
| 13 | 🟠 HIGH | Backend | Add inventory tracking to orders | 3 hrs |
| 6 | 🟠 HIGH | Frontend | Add error handling to HomePagegg | 1.5 hrs |
| 18 | 🟡 MEDIUM | Backend | Add structured logging/audit trail | 2 hrs |
| 19 | 🟡 MEDIUM | Backend | Add rate limiting | 1 hr |
| 14 | 🟡 MEDIUM | Backend | Validate pool deadline bounds | 30 min |
| 15 | 🟡 MEDIUM | Backend | Validate bulk import | 1.5 hrs |
| 4 | 🟡 MEDIUM | Frontend | Add `intl` package dependency | 5 min |
| 5 | 🟡 MEDIUM | Frontend | Fix type safety in API responses | 1 hr |
| 7 | 🟡 MEDIUM | Frontend | Fix Bearer token handling | 30 min |
| 17 | 🟡 MEDIUM | Backend | Secure CORS configuration | 30 min |
| 16 | 🟡 MEDIUM | Backend | Disable dev endpoints in production | 30 min |
| 9 | 🟢 LOW | Frontend | Replace hardcoded localhost URL | 30 min |
| 20 | 🟢 LOW | Backend | Add response DTOs for type safety | 2 hrs |

**Critical Path (Do These First - 11 hours):**
1. Issue #10: JWT authentication
2. Issue #11: Supplier ownership validation
3. Issue #1: Merge Product models
4. Issue #21: Align frontend/backend data structures
5. Issue #2: Consolidate HTTP clients
6. Issue #3: Fix widget constructors
7. Issue #12: Pool validation
8. Issue #13: Inventory tracking (large but critical)

---

## CONCLUSION

This full-stack app has **significant production-blocking issues**:

- **Security:** MVP auth is trivially bypassable; supplier data can be spoofed
- **Data Integrity:** Pools can be overcommitted; no inventory tracking
- **Frontend/Backend Mismatch:** UI models don't match API responses (runtime crashes)
- **Architecture:** Duplicate clients, duplicate models, unclear integration path

**Recommended action:** Fix critical path items (#10, #11, #1, #21, #2, #3, #12, #13) before any production deployment. Estimated time: **~11 hours of focused development**.

After these 8 items are complete, the app will be functionally testable end-to-end with basic security in place.

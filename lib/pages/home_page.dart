/*
HOME PAGE - DUAL SUPPLY MARKETS E-COMMERCE

MAIN SECTIONS:
1. APP BAR:
   - Logo: "AfroPool"
   - Shopping cart with badge
   - Notification icon

2. WELCOME BANNER:
   - "Shop from Nigeria & Korea"
   - Subtitle: "Pool orders, save money"

3. SUPPLIER ORIGIN FILTER:
   - Three toggle buttons: [ALL] [🇳🇬 NIGERIA] [🇰🇷 KOREA]
   - Active filter highlighted in blue
   - Show count: "12 Nigerian • 8 Korean products"

4. CATEGORY FILTER CHIPS:
   - Scrollable row: [All] [Beauty] [Fashion] [Electronics] [Home] [Food]
   - Active category has blue background

5. PRODUCT GRID (2 COLUMNS):
   Each product card shows:
   - FLAG BADGE: 🇳🇬 or 🇰🇷 top-left
   - PRODUCT IMAGE: Network image with placeholder
   - TITLE: 2 lines max, ellipsis
   - PRICE: "15,000 XAF" (formatted with commas)
   - MOQ PROGRESS: Linear bar + "25/50 items"
   - SHIPPING ESTIMATE: "3-7 days" (Nigeria) or "14-21 days" (Korea)
   - JOIN POOL BUTTON: Blue with icon

6. FLOATING ACTION BUTTON:
   - "My Pools" with pool count badge

7. BOTTOM NAVIGATION BAR:
   - Home (active)
   - Search
   - My Pools
   - Profile

DATA:
- Use mock data with Nigerian and Korean products
- Products should have: id, title, price, images, supplierOrigin, moq, currentOrders
- Nigerian examples: Ankara fabric, spices, crafts
- Korean examples: K-beauty, snacks, tech accessories
*/

import 'dart:async';

import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_client.dart';
import '../services/mvp_auth.dart';
import '../services/pool_service.dart';
import '../services/product_service.dart';
import '../services/user_store.dart';
import '../widgets/product_card.dart';
import '../widgets/role_mode_banner.dart';
import '../widgets/supplier_filter.dart';
import '../app/app_role.dart';
import '../widgets/role_switch_action.dart';

class HomePage extends StatefulWidget {
  final AppRole currentRole;
  final ValueChanged<AppRole> onRoleChanged;

  const HomePage({
    super.key,
    required this.currentRole,
    required this.onRoleChanged,
  });

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  late final ApiClient _apiClient;
  late final ProductService _productService;
  late final PoolService _poolService;

  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  String _selectedSupplierFilter = 'all';
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  Object? _loadError;
  bool _isCommitting = false;
  Timer? _countdownTicker;

  final List<String> _categories = [
    'All',
    'Beauty',
    'Fashion',
    'Electronics',
    'Home',
    'Food',
  ];

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient(
      userIdProvider: () async => await UserStore.getUserId() ?? MvpAuth.userId,
    );
    _productService = ProductService(apiClient: _apiClient);
    _poolService = PoolService(apiClient: _apiClient);
    _loadProducts();

    _countdownTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _apiClient.close();
    _countdownTicker?.cancel();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final products = await _productService.listProducts();
      if (!mounted) return;

      _allProducts = products;
      _filterProducts();
    } catch (err) {
      if (!mounted) return;

      setState(() {
        _loadError = err;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load products.')),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterProducts() {
    final hasKnownSupplierOrigins = _allProducts.any((p) {
      final origin = p.supplierOrigin.toLowerCase();
      return origin == 'nigeria' || origin == 'korea';
    });

    setState(() {
      _filteredProducts = _allProducts.where((product) {
        // Supplier filter
        final supplierMatch =
            _selectedSupplierFilter == 'all' ||
            (!hasKnownSupplierOrigins) ||
            product.supplierOrigin.toLowerCase() ==
                _selectedSupplierFilter.toLowerCase();

        // Category filter
        final categoryMatch =
            _selectedCategory == 'All' || product.category == _selectedCategory;

        // Search filter (simple title contains)
        final searchMatch =
            _searchController.text.isEmpty ||
            product.title.toLowerCase().contains(
              _searchController.text.toLowerCase(),
            );

        return supplierMatch && categoryMatch && searchMatch;
      }).toList();
    });
  }

  void _onSupplierFilterChanged(String filter) {
    setState(() {
      _selectedSupplierFilter = filter;
      _filterProducts();
    });
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
      _filterProducts();
    });
  }

  Future<void> _showCommitDialog({
    required String poolId,
    required String productTitle,
  }) async {
    final controller = TextEditingController(text: '1');
    bool isSubmitting = false;
    String? errorText;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          final navigator = Navigator.of(dialogContext);

          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              Future<void> submit() async {
                if (isSubmitting) return;

                final raw = controller.text.trim();
                final qty = int.tryParse(raw);
                if (qty == null || qty <= 0) {
                  setDialogState(() => errorText = 'Enter a quantity >= 1');
                  return;
                }

                setDialogState(() {
                  isSubmitting = true;
                  errorText = null;
                });
                setState(() => _isCommitting = true);

                var didCloseDialog = false;

                try {
                  await _poolService.commitToPool(poolId: poolId, qty: qty);
                  if (!mounted) return;

                  didCloseDialog = true;
                  navigator.pop();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Committed $qty item(s) to the pool.'),
                    ),
                  );

                  await _loadProducts();
                } catch (err) {
                  setDialogState(
                    () => errorText = _compactError(err.toString()),
                  );
                } finally {
                  if (mounted) setState(() => _isCommitting = false);
                  if (!didCloseDialog) {
                    setDialogState(() => isSubmitting = false);
                  }
                }
              }

              return AlertDialog(
                title: const Text('Join Pool'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      productTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      enabled: !isSubmitting,
                      decoration: InputDecoration(
                        labelText: 'Quantity',
                        hintText: 'e.g. 10',
                        errorText: errorText,
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => submit(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'MVP auth: x-user-id = ${MvpAuth.userId}',
                      style: Theme.of(dialogContext).textTheme.bodySmall
                          ?.copyWith(color: Colors.grey[700]),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: isSubmitting ? null : () => navigator.pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: isSubmitting ? null : submit,
                    child: isSubmitting
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Commit'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final showEmptyState = !_isLoading && _filteredProducts.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text('AfroPool'),
        actions: [
          RoleSwitchAction(
            currentRole: widget.currentRole,
            onRoleChanged: widget.onRoleChanged,
          ),
          IconButton(icon: Icon(Icons.notifications), onPressed: () {}),
          Stack(
            children: [
              IconButton(icon: Icon(Icons.shopping_cart), onPressed: () {}),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    '3', // Cart count
                    style: TextStyle(color: Colors.white, fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Welcome Banner
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shop from Nigeria & Korea',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Pool orders, save money',
                  style: TextStyle(fontSize: 16, color: Colors.blue[700]),
                ),
              ],
            ),
          ),

          RoleModeBanner(
            currentRole: widget.currentRole,
            onRoleChanged: widget.onRoleChanged,
          ),

          // Search Bar
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) => _filterProducts(),
            ),
          ),

          // Supplier Filter
          SupplierFilter(
            selectedFilter: _selectedSupplierFilter,
            onFilterChanged: _onSupplierFilterChanged,
            isLoading: _isLoading,
          ),

          // Category Chips
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                String category = _categories[index];
                bool isSelected = category == _selectedCategory;
                return Container(
                  margin: EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (_) => _onCategorySelected(category),
                    backgroundColor: Colors.white,
                    selectedColor: Colors.blue,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                  ),
                );
              },
            ),
          ),

          // Product Grid
          Expanded(
            child: _isLoading && _filteredProducts.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : showEmptyState
                    ? _EmptyState(
                        hasError: _loadError != null,
                        onRetry: _loadProducts,
                      )
                    : GridView.builder(
                        padding: EdgeInsets.all(16),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.75,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, index) {
                          Product product = _filteredProducts[index];
                          final poolId = product.poolSummary?.id;
                          final poolStatus =
                              product.poolSummary?.status.trim().toUpperCase();
                          final canJoinPool =
                              poolId != null && poolStatus == 'OPEN';

                          return ProductCard(
                            product: product,
                            readOnly: false,
                            onTap: () {
                              // Navigate to product detail
                            },
                            onLongPress: () {
                              // Add to wishlist
                            },
                            onJoinPool: () async {
                              final resolvedPoolId = poolId;
                              if (!canJoinPool || resolvedPoolId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('No open pool available.'),
                                  ),
                                );
                                return;
                              }
                              if (_isCommitting) return;
                              await _showCommitDialog(
                                poolId: resolvedPoolId,
                                productTitle: product.title,
                              );
                            },
                            onBuyNow: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Buy Now is not implemented yet.'),
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0, // Home is active
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'My Pools'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        onTap: (index) {
          // Handle navigation
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: Icon(Icons.group),
        label: Text('My Pools (5)'), // Pool count
      ),
    );
  }
}

String _compactError(String message) {
  final trimmed = message.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (trimmed.length <= 140) return trimmed;
  return '${trimmed.substring(0, 140)}...';
}

class _EmptyState extends StatelessWidget {
  final bool hasError;
  final Future<void> Function() onRetry;

  const _EmptyState({required this.hasError, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasError ? Icons.cloud_off : Icons.search_off,
              size: 42,
              color: Colors.grey,
            ),
            const SizedBox(height: 12),
            Text(
              hasError ? 'Unable to load products.' : 'No products found.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasError
                  ? 'Check that the backend API is running and try again.'
                  : 'Try changing filters or search terms.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => onRetry(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

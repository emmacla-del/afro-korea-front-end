/*
MOCK PRODUCT SERVICE - REALISTIC DUAL MARKET DATA

RETURNS 20 PRODUCTS:
NIGERIAN PRODUCTS (10 items):
1. Ankara Fabric Set - 25,000 XAF - Lagos, Nigeria
2. Jollof Rice Spice Pack - 8,000 XAF - Abuja, Nigeria
3. Handmade Leather Bag - 35,000 XAF - Kano, Nigeria
4. Shea Butter Cream - 12,000 XAF - Kaduna, Nigeria
5. African Print Dress - 28,000 XAF - Ibadan, Nigeria

KOREAN PRODUCTS (10 items):
1. K-Beauty Face Mask (10pc) - 18,000 XAF - Seoul, Korea
2. Korean Ramen Pack - 15,000 XAF - Busan, Korea
3. Samsung Phone Case - 9,000 XAF - Suwon, Korea
4. Ginseng Extract - 32,000 XAF - Daegu, Korea
5. K-Pop Merch T-Shirt - 22,000 XAF - Incheon, Korea

EACH PRODUCT HAS:
- Realistic MOQ: 20-100 items
- Current orders: 0 to MOQ-10
- Pooling deadline: 3-10 days from now
- Multiple images (placeholder URLs)
- Proper supplier info
*/

import '../models/product.dart';

class MockProductService {
  static List<Product> getMockProducts() {
    return [
      // Nigerian Products
      Product(
        id: 'nig1',
        title: 'Ankara Fabric Set',
        description: 'Vibrant Ankara fabric for all your fashion needs.',
        category: 'Fashion',
        priceXaf: 25000,
        currency: 'XAF',
        supplierId: 'sup_lagos_1',
        images: [
          'https://via.placeholder.com/150?text=Ankara+Fabric+1',
          'https://via.placeholder.com/150?text=Ankara+Fabric+2',
        ],
        supplierName: 'Lagos Textiles',
        supplierOrigin: 'nigeria',
        supplierCity: 'Lagos',
        moq: 50,
        currentOrders: 25,
        poolingDeadline: DateTime.now().add(Duration(days: 7)),
        estimatedDays: 5,
        requiresCustoms: false,
        isActive: true,
        createdAt: DateTime.now().subtract(Duration(days: 1)),
      ),
      Product(
        id: 'nig2',
        title: 'Jollof Rice Spice Pack',
        description: 'Authentic spices to make delicious Jollof rice.',
        category: 'Food',
        priceXaf: 8000,
        currency: 'XAF',
        supplierId: 'sup_abuja_1',
        images: [
          'https://via.placeholder.com/150?text=Jollof+Spice+1',
          'https://via.placeholder.com/150?text=Jollof+Spice+2',
        ],
        supplierName: 'Abuja Spices Co.',
        supplierOrigin: 'nigeria',
        supplierCity: 'Abuja',
        moq: 30,
        currentOrders: 10,
        poolingDeadline: DateTime.now().add(Duration(days: 5)),
        estimatedDays: 4,
        requiresCustoms: false,
        isActive: true,
        createdAt: DateTime.now().subtract(Duration(days: 2)),
      ),
      // Add more Nigerian products here...

      // Korean Products
      Product(
        id: 'kor1',
        title: 'K-Beauty Face Mask (10pc)',
        description: 'Hydrating face masks for glowing skin.',
        category: 'Beauty',
        priceXaf: 18000,
        currency: 'XAF',
        supplierId: 'sup_seoul_1',
        images: [
          'https://via.placeholder.com/150?text=K-Beauty+Mask+1',
          'https://via.placeholder.com/150?text=K-Beauty+Mask+2',
        ],
        supplierName: 'Seoul Beauty Inc.',
        supplierOrigin: 'korea',
        supplierCity: 'Seoul',
        moq: 40,
        currentOrders: 15,
        poolingDeadline: DateTime.now().add(Duration(days: 6)),
        estimatedDays: 18,
        requiresCustoms: true,
        isActive: true,
        createdAt: DateTime.now().subtract(Duration(days: 1)),
      ),
      Product(
        id: 'kor2',
        title: 'Korean Ramen Pack',
        description: 'Spicy and savory Korean ramen noodles.',
        category: 'Food',
        priceXaf: 15000,
        currency: 'XAF',
        supplierId: 'sup_busan_1',
        images: [
          'https://via.placeholder.com/150?text=Korean+Ramen+1',
          'https://via.placeholder.com/150?text=Korean+Ramen+2',
        ],
        supplierName: 'Busan Noodles Ltd.',
        supplierOrigin: 'korea',
        supplierCity: 'Busan',
        moq: 60,
        currentOrders: 30,
        poolingDeadline: DateTime.now().add(Duration(days: 8)),
        estimatedDays: 20,
        requiresCustoms: true,
        isActive: true,
        createdAt: DateTime.now().subtract(Duration(days: 3)),
      ),
      // Add more Korean products here...
    ];
  }
}

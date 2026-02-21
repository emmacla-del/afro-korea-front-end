/*
PRODUCT CARD WIDGET WITH DUAL MARKET SUPPORT
*/

import 'package:flutter/material.dart';
import '../models/product.dart';

const _flagNigeria = '\u{1F1F3}\u{1F1EC}';
const _flagKorea = '\u{1F1F0}\u{1F1F7}';
const _truckEmoji = '\u{1F69A}';
const _planeEmoji = '\u2708\uFE0F';
const _unknownEmoji = '\u2753';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onJoinPool;
  final VoidCallback onBuyNow;
  final bool readOnly;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.onLongPress,
    required this.onJoinPool,
    required this.onBuyNow,
    this.readOnly = false,
  });

  Color _getProgressColor(double progress) {
    if (progress >= 0.7) return Colors.green;
    if (progress >= 0.3) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final rawProgress = product.moq == 0
        ? 0.0
        : (product.currentOrders / product.moq);
    final progress = rawProgress < 0
        ? 0.0
        : rawProgress > 1
        ? 1.0
        : rawProgress;

    final formattedPrice = product.priceXaf
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );

    final origin = product.supplierOrigin.toLowerCase();
    final isNigeria = origin == 'nigeria';
    final isKorea = origin == 'korea';
    final flag = isNigeria
        ? _flagNigeria
        : isKorea
        ? _flagKorea
        : _unknownEmoji;

    final customsSuffix = product.requiresCustoms ? ' + customs' : '';
    final shippingEmoji = product.requiresCustoms || product.estimatedDays >= 10
        ? _planeEmoji
        : _truckEmoji;
    final shippingLabel =
        '$shippingEmoji Est. ${product.estimatedDays} days$customsSuffix';
    final imageUrl = product.images.isNotEmpty ? product.images.first : null;

    final pool = product.poolSummary;
    final poolStatus = pool?.status.trim().toUpperCase();
    final poolDeadline = pool?.deadlineAt;
    final paymentWindowEndsAt = pool?.paymentWindowEndsAt;
    final joinEnabled = pool != null &&
        poolStatus == 'OPEN' &&
        !(product.moq > 0 && product.currentOrders >= product.moq);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: const [
            BoxShadow(
              color: Color(0x4D9E9E9E),
              blurRadius: 6,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12.0),
                  ),
                  child: AspectRatio(
                    // Keep the image shorter to avoid vertical overflows in grid layouts.
                    aspectRatio: 16 / 9,
                    child: imageUrl == null
                        ? Container(
                            color: Colors.grey[200],
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.image_not_supported,
                              color: Colors.grey,
                            ),
                          )
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[200],
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.image_not_supported,
                                  color: Colors.grey,
                                ),
                              );
                            },
                          ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isNigeria ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(flag, style: const TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(6.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$formattedPrice XAF',
                    style: const TextStyle(color: Colors.green, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _buildSupplierLine(
                      supplierCity: product.supplierCity,
                      isNigeria: isNigeria,
                      isKorea: isKorea,
                    ),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  if (poolStatus != null && poolStatus.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _PoolStatusBadge(
                        status: poolStatus,
                      ),
                    ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: progress,
                    color: _getProgressColor(progress),
                    backgroundColor: Colors.grey[200],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${product.currentOrders}/${product.moq} items (${(progress * 100).toStringAsFixed(0)}%)',
                    style: const TextStyle(fontSize: 11),
                  ),
                  if (poolStatus != null && poolStatus.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _buildPoolStatusLine(
                          poolStatus,
                          deadlineAt: poolDeadline,
                          paymentWindowEndsAt: paymentWindowEndsAt,
                        ),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isNigeria ? Colors.green[100] : Colors.orange[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      shippingLabel,
                      style: TextStyle(
                        color: isNigeria ? Colors.green : Colors.orange,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (!readOnly)
                    SizedBox(
                      height: 36,
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: joinEnabled ? onJoinPool : null,
                              icon: const Icon(Icons.groups, size: 16),
                              label: Text(
                                pool == null
                                    ? 'No Pool'
                                    : poolStatus != 'OPEN'
                                    ? _joinDisabledLabel(poolStatus ?? '')
                                    : (product.moq > 0 &&
                                              product.currentOrders >= product.moq)
                                          ? 'Pool Full'
                                          : 'Join Pool',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                textStyle: const TextStyle(fontSize: 12),
                                disabledForegroundColor: Colors.grey,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: onBuyNow,
                              icon: const Icon(Icons.shopping_bag, size: 16),
                              label: const Text('Buy Now'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _buildSupplierLine({
  required String supplierCity,
  required bool isNigeria,
  required bool isKorea,
}) {
  final originLabel = isNigeria
      ? 'Nigeria'
      : isKorea
      ? 'Korea'
      : 'Unknown';

  final city = supplierCity.trim();
  if (city.isEmpty) return 'From $originLabel';
  return 'From $city, $originLabel';
}

String _buildPoolStatusLine(
  String status, {
  required DateTime? deadlineAt,
  required DateTime? paymentWindowEndsAt,
}) {
  final normalized = status.trim().toUpperCase();

  DateTime? countdownTarget;
  String prefix;

  switch (normalized) {
    case 'OPEN':
      prefix = 'Pool: OPEN';
      countdownTarget = deadlineAt;
      break;
    case 'PAYMENT_WINDOW':
      prefix = 'Pool: PAYMENT WINDOW';
      countdownTarget = paymentWindowEndsAt;
      break;
    case 'EXPIRED':
      return 'Pool: EXPIRED';
    case 'FAILED_PAYMENT':
      return 'Pool: FAILED PAYMENT';
    case 'PURCHASED':
      return 'Pool: PURCHASED';
    default:
      prefix = 'Pool: $normalized';
      countdownTarget = deadlineAt ?? paymentWindowEndsAt;
      break;
  }

  if (countdownTarget == null) return prefix;

  final now = DateTime.now();
  final remaining = countdownTarget.difference(now);
  if (remaining.inSeconds <= 0) return '$prefix | ended';

  final days = remaining.inDays;
  if (days >= 2) return '$prefix | ends in ${days}d';

  final hours = remaining.inHours;
  if (hours >= 2) return '$prefix | ends in ${hours}h';

  final minutes = remaining.inMinutes;
  return '$prefix | ends in ${minutes}m';
}

String _joinDisabledLabel(String poolStatus) {
  switch (poolStatus.trim().toUpperCase()) {
    case 'PAYMENT_WINDOW':
      return 'Pay Window';
    case 'EXPIRED':
      return 'Expired';
    case 'FAILED_PAYMENT':
      return 'Failed';
    case 'PURCHASED':
      return 'Purchased';
    default:
      return 'Pool Closed';
  }
}

class _PoolStatusBadge extends StatelessWidget {
  final String status;

  const _PoolStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toUpperCase();

    final (label, bg, fg, icon) = switch (normalized) {
      'OPEN' => ('OPEN', Colors.blue, Colors.white, Icons.lock_open),
      'PAYMENT_WINDOW' =>
        ('PAYMENT WINDOW', Colors.deepOrange, Colors.white, Icons.timer),
      'EXPIRED' => ('EXPIRED', Colors.grey, Colors.white, Icons.schedule),
      'FAILED_PAYMENT' =>
        ('FAILED PAYMENT', Colors.red, Colors.white, Icons.error_outline),
      'PURCHASED' => ('PURCHASED', Colors.green, Colors.white, Icons.check),
      _ => (normalized, Colors.black54, Colors.white, Icons.info_outline),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}


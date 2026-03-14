import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/image_utils.dart';

class TeamDealsPage extends StatefulWidget {
  const TeamDealsPage({super.key});

  @override
  State<TeamDealsPage> createState() => _TeamDealsPageState();
}

class _TeamDealsPageState extends State<TeamDealsPage> {
  List<Map<String, dynamic>> _deals = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDeals();
  }

  Future<void> _loadDeals() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final deals = await ApiService.instance.getOpenTeamDeals();
      setState(() {
        _deals = deals;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _joinDeal(String poolId) async {
    try {
      await ApiService.instance.joinTeamDeal(poolId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 Successfully joined the deal!')),
      );
      _loadDeals();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Failed to join: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadDeals, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_deals.isEmpty) {
      return const Center(child: Text('No team deals available right now.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _deals.length,
      itemBuilder: (context, index) {
        final deal = _deals[index];
        return _TeamDealCard(deal: deal, onJoin: () => _joinDeal(deal['id']));
      },
    );
  }
}

class _TeamDealCard extends StatelessWidget {
  final Map<String, dynamic> deal;
  final VoidCallback onJoin;

  const _TeamDealCard({required this.deal, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    final product = deal['variant']['product'];
    final originalPrice = deal['unitPriceXafSnapshot'];
    final teamPrice = deal['teamPrice'];
    final current = deal['currentBuyers'] ?? 0;
    final min = deal['minBuyers'] ?? 2;
    final progress = current / min;
    final deadline = DateTime.parse(deal['deadlineAt']);
    final timeLeft = deadline.difference(DateTime.now());

    // Extract image URL safely from either format:
    // - plain string:  '/uploads/products/...'
    // - object:        { url: '/uploads/products/...' }
    // Backend currently returns [] for team deal products —
    // the placeholder icon will show until the backend includes images.
    String? rawImageUrl;
    final images = product['images'];
    if (images != null && images is List && images.isNotEmpty) {
      final first = images[0];
      if (first is Map) {
        rawImageUrl = first['url']?.toString();
      } else if (first is String) {
        rawImageUrl = first;
      }
    }
    final imageUrl = getImageUrl(rawImageUrl); // ✅ converts to absolute URL

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Show image if available, placeholder if not
          if (imageUrl.isNotEmpty)
            Image.network(
              imageUrl,
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 150,
                color: Colors.grey[300],
                child: const Icon(Icons.image_not_supported),
              ),
            )
          else
            Container(
              height: 150,
              color: Colors.grey[200],
              child: const Center(
                child: Icon(Icons.image, size: 48, color: Colors.grey),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['title'] ?? 'Unknown product',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'by ${product['supplier']?['displayName'] ?? 'Supplier'}',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '$originalPrice FCFA',
                      style: const TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$teamPrice FCFA',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: Colors.grey[200],
                  color: Colors.green,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '👥 $current/$min joined',
                      style: const TextStyle(fontSize: 12),
                    ),
                    _CountdownTimer(expiresAt: deadline),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onJoin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: timeLeft.inHours < 3
                          ? Colors.orange
                          : Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      timeLeft.inHours < 3
                          ? '🔥 URGENT - JOIN NOW'
                          : 'JOIN TEAM DEAL',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownTimer extends StatefulWidget {
  final DateTime expiresAt;
  const _CountdownTimer({required this.expiresAt});

  @override
  State<_CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<_CountdownTimer> {
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.expiresAt.difference(DateTime.now());
    Future.delayed(const Duration(seconds: 1), _updateTimer);
  }

  void _updateTimer() {
    if (!mounted) return;
    setState(() {
      _remaining = widget.expiresAt.difference(DateTime.now());
    });
    if (_remaining.inSeconds > 0) {
      Future.delayed(const Duration(seconds: 1), _updateTimer);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining.isNegative) {
      return const Text('⏰ Expired', style: TextStyle(fontSize: 12));
    }
    final hours = _remaining.inHours;
    final minutes = _remaining.inMinutes % 60;
    final isUrgent = hours < 3;
    return Text(
      '⏱ ${hours}h ${minutes}m left',
      style: TextStyle(
        fontSize: 12,
        color: isUrgent ? Colors.red : Colors.orange,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

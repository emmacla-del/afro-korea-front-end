import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart'; // 👈 added
import '../services/api_service.dart';

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
      final validDeals = deals.where((deal) {
        return deal['variant'] != null &&
            (deal['variant'] as Map).containsKey('product') &&
            deal['variant']['product'] != null;
      }).toList();
      setState(() {
        _deals = validDeals;
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

  // ✅ Safely extract image URL from either format:
  // - plain string:  'https://res.cloudinary.com/...'
  // - object:        { url: 'https://...', id: '...' }
  String? _extractImageUrl(dynamic images) {
    if (images == null) return null;
    if (images is! List || images.isEmpty) return null;
    final first = images.first;
    if (first is String) return first;
    if (first is Map) return first['url']?.toString();
    return null;
  }

  // 👇 share deal with referral code – UPDATED with correct Netlify domain
  void _shareDeal(BuildContext context, String poolId) async {
    try {
      final stats = await ApiService.instance.getReferralStats();
      final code = stats['referralCode'];
      final url =
          'https://magnificent-frangipane-261faf.netlify.app/#/team-deals?poolId=$poolId&ref=$code';
      Share.share('Check out this great team deal! $url', subject: 'Team Deal');
    } catch (e) {
      // If stats fail, share without referral
      final url =
          'https://magnificent-frangipane-261faf.netlify.app/#/team-deals?poolId=$poolId';
      Share.share('Check out this great team deal! $url', subject: 'Team Deal');
    }
  }

  @override
  Widget build(BuildContext context) {
    final variant = deal['variant'];
    if (variant == null) return const SizedBox.shrink();

    final product = variant['product'];
    if (product == null) return const SizedBox.shrink();

    final originalPrice = deal['unitPriceXafSnapshot'] ?? 0;
    final teamPrice = deal['teamPrice'] ?? 0;
    final current = deal['currentBuyers'] ?? 0;
    final min = deal['minBuyers'] ?? 2;
    final progress = (min > 0) ? (current / min) : 0.0;
    final deadline = DateTime.tryParse(deal['deadlineAt'] ?? '');
    if (deadline == null) return const SizedBox.shrink();
    final timeLeft = deadline.difference(DateTime.now());

    final imageUrl = _extractImageUrl(product['images']);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 👇 Image with share button overlay
          Stack(
            children: [
              if (imageUrl != null)
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
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.share, size: 20),
                    onPressed: () => _shareDeal(context, deal['id']),
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['title']?.toString() ?? 'Unknown product',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'by ${product['supplier']?['displayName']?.toString() ?? 'Supplier'}',
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

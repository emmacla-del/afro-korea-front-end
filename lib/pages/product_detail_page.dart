import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

import '../models/product.dart';
import '../services/api_service.dart';

final FlutterLocalNotificationsPlugin localNotifications =
    FlutterLocalNotificationsPlugin();

class ProductDetailPage extends StatefulWidget {
  final String productId;
  final String? initialPoolId; // 👈 NEW: passed when user clicked "JOIN DEAL"

  const ProductDetailPage({
    super.key,
    required this.productId,
    this.initialPoolId,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  Product? _product;
  bool _isLoading = true;
  String? _error;

  late Duration _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();
    _initNotifications();
    _fetchProduct();
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await localNotifications.initialize(settings);
  }

  Future<void> _fetchProduct() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final product = await ApiService.instance.fetchProductById(
        widget.productId,
      );
      if (!mounted) return;
      setState(() {
        _product = product;
        _isLoading = false;
      });
      _startTimerIfNeeded();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _startTimerIfNeeded() {
    if (_product == null || _product!.isExpired) return;
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining();
    });
  }

  void _updateRemaining() {
    if (!mounted) return;
    setState(() {
      _remaining = _product?.timeLeft ?? Duration.zero;
    });
    if (_remaining.inSeconds <= 0) {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    if (d.inSeconds <= 0) return "00:00:00";
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$hours:$minutes:$seconds";
  }

  void _showShareModal() {
    final userId = 'USER_ID'; // Replace with actual user ID from auth
    final shareLink =
        "https://afropool.app/product/${widget.productId}?ref=$userId";

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Invite Friends & Unlock Discount!',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Share this link and get your friends to join the deal.',
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chat, color: Colors.green, size: 32),
                    onPressed: () =>
                        launchUrl(Uri.parse("https://wa.me/?text=$shareLink")),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.sms,
                      color: Colors.blueAccent,
                      size: 32,
                    ),
                    onPressed: () =>
                        launchUrl(Uri.parse("sms:?body=$shareLink")),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.grey, size: 32),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: shareLink));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Link copied to clipboard!"),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.share,
                      color: Colors.orange,
                      size: 32,
                    ),
                    onPressed: () => Share.share(shareLink),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _scheduleExpiryNotification(DateTime expiry) async {
    final location = tz.local;
    final scheduledTime = tz.TZDateTime.from(
      expiry.subtract(const Duration(hours: 1)),
      location,
    );
    if (scheduledTime.isAfter(tz.TZDateTime.now(location))) {
      await localNotifications.zonedSchedule(
        _product!.activeTeamDealPoolId.hashCode,
        '⏰ Deal ending soon!',
        'Your group deal ends in 1 hour. Invite more friends now!',
        scheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'expiry_channel',
            'Deal Expiry',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  // ─────────────────────────────── JOIN EXISTING DEAL ───────────────────────────────
  Future<void> _handleJoinDeal() async {
    if (_product == null) return;
    final poolId = _product!.activeTeamDealPoolId;
    if (poolId == null) return;
    try {
      await ApiService.instance.joinTeamDeal(poolId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '✅ You have joined this procurement. Invite others to secure the deal.',
          ),
          backgroundColor: Color(0xFF00C471),
        ),
      );
      await _fetchProduct(); // refresh counts
      final expiry = _product?.expiryDate;
      if (expiry != null) await _scheduleExpiryNotification(expiry);
      _showShareModal();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to join: ${e.toString()}')),
      );
    }
  }

  // ─────────────────────────────── START NEW DEAL ───────────────────────────────
  Future<void> _startDeal() async {
    if (_product == null) return;
    // Use the first variant (or let user choose – for now, pick first)
    final variantId = _product!.variants?.first['id'] as String?;
    if (variantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No variant available to start a deal.')),
      );
      return;
    }
    try {
      // Create a new team deal – adjust teamPrice/minBuyers as appropriate
      final result = await ApiService.instance.createTeamDeal(
        variantId: variantId,
        teamPrice: (_product!.price! - 10).toInt(), // example discount
        minBuyers: 2, // default
      );
      final poolId = result['id'] as String;
      // Automatically join the newly created pool
      await ApiService.instance.joinTeamDeal(poolId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '🏁 Deal initiative started. You are the lead buyer. Share now to reach the minimum.',
          ),
          backgroundColor: Color(0xFF00C471),
        ),
      );
      await _fetchProduct(); // refresh to show new pool
      final expiry = _product?.expiryDate;
      if (expiry != null) await _scheduleExpiryNotification(expiry);
      _showShareModal();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start deal: ${e.toString()}')),
      );
    }
  }

  Widget _buildCountdownAndProgress() {
    if (_product == null) return const SizedBox.shrink();
    final product = _product!;
    if (product.isExpired) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            "This procurement has ended",
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
    final current = product.currentBuyers ?? 0;
    final min = product.minBuyers ?? 0;
    final progress = min > 0 ? current / min : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFF9),
        border: Border.all(
          color: const Color(0xFF00C471).withValues(alpha: 0.2),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.flash_on, color: Colors.orange, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    "$current joined",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Text(
                "Ends in ${_formatDuration(product.timeLeft)}",
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF00C471)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            min > current
                ? "Needs ${min - current} more participants to unlock the discount"
                : "Minimum reached! Deal is active.",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyBottomBar() {
    if (_product == null) return const SizedBox.shrink();
    final product = _product!;
    final soloPrice = product.price ?? 0;
    final hasActive = product.hasActiveTeamDeal && !product.isExpired;
    final teamPrice = product.teamPrice ?? soloPrice;
    final isExpired = product.isExpired;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Buy Alone - not implemented yet'),
                    ),
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "${soloPrice.toStringAsFixed(0)} XAF",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const Text(
                      "Buy Alone",
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 5,
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: isExpired
                      ? null
                      : (hasActive ? _handleJoinDeal : _startDeal),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isExpired
                        ? Colors.grey
                        : (hasActive
                              ? const Color(0xFFFF4800)
                              : Colors.blueGrey.shade700),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        hasActive
                            ? "${teamPrice.toStringAsFixed(0)} XAF"
                            : "START DEAL",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        isExpired
                            ? "PROCUREMENT ENDED"
                            : (hasActive
                                  ? "JOIN PROCUREMENT"
                                  : "INITIATE PROCUREMENT"),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $_error'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _fetchProduct,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_product == null) {
      return const Scaffold(body: Center(child: Text('Product not found')));
    }

    final product = _product!;
    final imageUrl = product.images?.isNotEmpty == true
        ? product.images!.first
        : null;

    return Scaffold(
      appBar: AppBar(title: Text(product.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null)
              Image.network(
                imageUrl,
                width: double.infinity,
                height: 300,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 300,
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: Icon(Icons.broken_image, size: 50),
                  ),
                ),
              )
            else
              Container(
                height: 300,
                color: Colors.grey.shade200,
                child: const Center(child: Icon(Icons.image, size: 50)),
              ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                product.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _buildCountdownAndProgress(),
            if (product.description != null && product.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(product.description!),
              ),
          ],
        ),
      ),
      bottomSheet: _buildStickyBottomBar(),
    );
  }
}

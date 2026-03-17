import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for Clipboard
import '../services/api_service.dart';
import '../services/user_store.dart';

class ProfilePage extends StatelessWidget {
  final VoidCallback onLogout;

  const ProfilePage({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 20),
        FutureBuilder<String?>(
          future: UserStore.getUserId(),
          builder: (context, snapshot) {
            final userId = snapshot.data ?? 'Not logged in';
            return Text(
              'User ID: $userId',
              style: const TextStyle(fontSize: 16),
            );
          },
        ),
        const SizedBox(height: 20),
        const _ReferralSection(), // 👈 NEW
        const SizedBox(height: 20),
        ElevatedButton(onPressed: onLogout, child: const Text('Logout')),
      ],
    );
  }
}

class _ReferralSection extends StatefulWidget {
  const _ReferralSection({super.key});

  @override
  __ReferralSectionState createState() => __ReferralSectionState();
}

class __ReferralSectionState extends State<_ReferralSection> {
  Map<String, dynamic>? _stats;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final stats = await ApiService.instance.getReferralStats();
      setState(() {
        _stats = stats;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      debugPrint('Error loading referral stats: $e');
    }
  }

  Future<void> _generateCode() async {
    try {
      final res = await ApiService.instance.generateReferralCode();
      setState(() {
        _stats ??= {};
        _stats!['referralCode'] = res['referralCode'];
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Referral code generated!')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Referral Program',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            if (_stats == null || _stats!['referralCode'] == null)
              ElevatedButton(
                onPressed: _generateCode,
                child: const Text('Generate Referral Code'),
              )
            else ...[
              ListTile(
                title: const Text('Your Code'),
                subtitle: Text(_stats!['referralCode']),
                trailing: IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: _stats!['referralCode']),
                    );
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('Copied!')));
                  },
                ),
              ),
              ListTile(
                title: const Text('Total Referrals'),
                trailing: Text('${_stats!['totalReferrals'] ?? 0}'),
              ),
              ListTile(
                title: const Text('Reward Balance'),
                trailing: Text('${_stats!['rewardBalance'] ?? 0} points'),
              ),
              const SizedBox(height: 8),
              const Text('Recent Transactions'),
              const SizedBox(height: 4),
              if (_stats!['transactions']?.isEmpty ?? true)
                const Text('No transactions yet')
              else
                ...(_stats!['transactions'] as List)
                    .take(5)
                    .map(
                      (tx) => ListTile(
                        title: Text(tx['description']),
                        trailing: Text(
                          '${tx['amount'] > 0 ? '+' : ''}${tx['amount']}',
                        ),
                        subtitle: Text(
                          DateTime.parse(
                            tx['createdAt'],
                          ).toLocal().toString().split(' ')[0],
                        ),
                      ),
                    ),
            ],
          ],
        ),
      ),
    );
  }
}

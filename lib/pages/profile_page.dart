import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for Clipboard
import '../services/api_service.dart';
import '../services/user_store.dart';
import '../models/neighbourhood.dart';

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
        const _LocationSection(), // Location editor
        const SizedBox(height: 20),
        const _ReferralSection(),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: onLogout, child: const Text('Logout')),
      ],
    );
  }
}

// ==================== Location Section (Cascading Dropdowns) ====================
class _LocationSection extends StatefulWidget {
  // ✅ FIX: Removed stray parameter 'c', use standard const constructor
  const _LocationSection({super.key});

  @override
  State<_LocationSection> createState() => _LocationSectionState();
}

class _LocationSectionState extends State<_LocationSection> {
  // Data
  List<Neighbourhood> _allNeighbourhoods = [];
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  // Selections
  Region? _selectedRegion;
  Division? _selectedDivision;
  Neighbourhood? _selectedNeighbourhood;

  // Derived lists
  List<Region> get _regions {
    final regions = _allNeighbourhoods
        .map((n) => n.division.region)
        .toSet()
        .toList();
    regions.sort((a, b) => a.name.compareTo(b.name));
    return regions;
  }

  List<Division> get _divisions {
    if (_selectedRegion == null) return [];
    return _allNeighbourhoods
        .where((n) => n.division.region.id == _selectedRegion!.id)
        .map((n) => n.division)
        .toSet()
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  List<Neighbourhood> get _neighbourhoods {
    if (_selectedDivision == null) return [];
    return _allNeighbourhoods
        .where((n) => n.division.id == _selectedDivision!.id)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Execute both futures and cast results explicitly
      final results = await Future.wait([
        ApiService.instance.fetchNeighbourhoods(),
        ApiService.instance.getUserProfile(),
      ]);

      // Cast to correct types
      final neighbourhoods = results[0] as List<Neighbourhood>;
      final profile = results[1] as Map<String, dynamic>;

      if (!mounted) return;

      // Extract current neighbourhood from profile (if any)
      Neighbourhood? currentNeighbourhood;
      if (profile['neighbourhood'] != null && profile['neighbourhood'] is Map) {
        currentNeighbourhood = Neighbourhood.fromJson(
          profile['neighbourhood'] as Map<String, dynamic>,
        );
      }

      setState(() {
        _allNeighbourhoods = neighbourhoods;
        _userProfile = profile;
        if (currentNeighbourhood != null) {
          _selectedRegion = currentNeighbourhood.division.region;
          _selectedDivision = currentNeighbourhood.division;
          _selectedNeighbourhood = currentNeighbourhood;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveLocation() async {
    if (_selectedNeighbourhood == null) return; // nothing to save
    setState(() => _isSaving = true);
    try {
      await ApiService.instance.updateProfile(
        neighbourhoodId: _selectedNeighbourhood!.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Location updated!')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Column(
        children: [
          Text('Error loading location data: $_error'),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
        ],
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Location',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Region dropdown
            DropdownButtonFormField<Region?>(
              initialValue: _selectedRegion,
              decoration: const InputDecoration(
                labelText: 'Region',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<Region?>(
                  value: null,
                  child: Text('Select a region'),
                ),
                ..._regions.map(
                  (region) => DropdownMenuItem<Region?>(
                    value: region,
                    child: Text(region.name),
                  ),
                ),
              ],
              onChanged: (region) {
                setState(() {
                  _selectedRegion = region;
                  _selectedDivision = null;
                  _selectedNeighbourhood = null;
                });
              },
            ),
            const SizedBox(height: 12),

            // Division dropdown
            DropdownButtonFormField<Division?>(
              initialValue: _selectedDivision,
              decoration: const InputDecoration(
                labelText: 'Division',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<Division?>(
                  value: null,
                  child: Text('Select a division'),
                ),
                ..._divisions.map(
                  (div) => DropdownMenuItem<Division?>(
                    value: div,
                    child: Text(div.name),
                  ),
                ),
              ],
              onChanged: _selectedRegion == null
                  ? null
                  : (div) {
                      setState(() {
                        _selectedDivision = div;
                        _selectedNeighbourhood = null;
                      });
                    },
            ),
            const SizedBox(height: 12),

            // Neighbourhood dropdown
            DropdownButtonFormField<Neighbourhood?>(
              initialValue: _selectedNeighbourhood,
              decoration: const InputDecoration(
                labelText: 'Neighbourhood',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<Neighbourhood?>(
                  value: null,
                  child: Text('Select a neighbourhood'),
                ),
                ..._neighbourhoods.map(
                  (hood) => DropdownMenuItem<Neighbourhood?>(
                    value: hood,
                    child: Text(hood.name),
                  ),
                ),
              ],
              onChanged: _selectedDivision == null
                  ? null
                  : (hood) {
                      setState(() => _selectedNeighbourhood = hood);
                    },
            ),
            const SizedBox(height: 16),

            // Save button (only if changed)
            if (_selectedNeighbourhood != null &&
                (_userProfile?['neighbourhood']?['id'] !=
                    _selectedNeighbourhood!.id))
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveLocation,
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Location'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ==================== Referral Section ====================
class _ReferralSection extends StatefulWidget {
  const _ReferralSection();

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
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Referral code generated!')));
    } catch (e) {
      if (!mounted) return;
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

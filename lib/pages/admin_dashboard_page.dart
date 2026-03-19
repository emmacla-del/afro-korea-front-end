import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AdminDashboardPage extends StatefulWidget {
  final VoidCallback onLogout;

  const AdminDashboardPage({super.key, required this.onLogout});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  List<Map<String, dynamic>> _pendingSuppliers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPendingSuppliers();
  }

  Future<void> _loadPendingSuppliers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final suppliers = await ApiService.instance.fetchPendingSuppliers();
      setState(() {
        _pendingSuppliers = suppliers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _verifySupplier(String supplierId) async {
    try {
      await ApiService.instance.verifySupplier(supplierId);
      // Remove from list or refresh
      _loadPendingSuppliers();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Supplier verified')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _rejectSupplier(String supplierId) async {
    try {
      await ApiService.instance.rejectSupplier(supplierId);
      _loadPendingSuppliers();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Supplier rejected')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPendingSuppliers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: $_error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadPendingSuppliers,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadPendingSuppliers,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Stats cards (optional)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Overview',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  'Pending Suppliers',
                                  _pendingSuppliers.length.toString(),
                                  Icons.pending_actions,
                                  Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildStatCard(
                                  'Total Suppliers',
                                  '?', // We can add later
                                  Icons.store,
                                  Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Pending Supplier Verifications',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (_pendingSuppliers.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('No pending suppliers'),
                      ),
                    )
                  else
                    ..._pendingSuppliers
                        .map((supplier) => _buildSupplierTile(supplier))
                        .toList(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(title, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSupplierTile(Map<String, dynamic> supplier) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              supplier['displayName'] ?? 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text('Country: ${supplier['country'] ?? 'N/A'}'),
            Text('City: ${supplier['city'] ?? 'N/A'}'),
            Text('Business Reg: ${supplier['businessRegNumber'] ?? 'N/A'}'),
            Text('Owner ID: ${supplier['ownerUserId'] ?? 'N/A'}'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _verifySupplier(supplier['id']),
                  icon: const Icon(Icons.check),
                  label: const Text('Verify'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _rejectSupplier(supplier['id']),
                  icon: const Icon(Icons.close),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

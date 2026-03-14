import 'package:flutter/material.dart';
import '../services/user_store.dart';

class ProfilePage extends StatelessWidget {
  final VoidCallback onLogout;

  const ProfilePage({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Profile', style: TextStyle(fontSize: 24)),
          const SizedBox(height: 20),
          FutureBuilder<String?>(
            future: UserStore.getUserId(),
            builder: (context, snapshot) {
              final userId = snapshot.data ?? 'Not logged in';
              return Text('User ID: $userId');
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: onLogout, child: const Text('Logout')),
        ],
      ),
    );
  }
}

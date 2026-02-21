import 'package:flutter/material.dart';
import '../app/app_role.dart';

class RoleModeBanner extends StatelessWidget {
  final AppRole currentRole;
  final ValueChanged<AppRole> onRoleChanged;

  const RoleModeBanner({
    super.key,
    required this.currentRole,
    required this.onRoleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final nextRole = currentRole == AppRole.customer
        ? AppRole.supplier
        : AppRole.customer;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_pin, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Mode: ${currentRole.label}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          TextButton(
            onPressed: () => onRoleChanged(nextRole),
            child: Text('Switch to ${nextRole.label}'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../app/app_role.dart';

class RoleSwitchAction extends StatelessWidget {
  final AppRole currentRole;
  final ValueChanged<AppRole> onRoleChanged;

  const RoleSwitchAction({
    super.key,
    required this.currentRole,
    required this.onRoleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AppRole>(
      tooltip: 'Switch role',
      initialValue: currentRole,
      onSelected: onRoleChanged,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(40),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withAlpha(90)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                currentRole == AppRole.customer
                    ? Icons.shopping_bag
                    : Icons.store,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                currentRole.label,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
      itemBuilder: (context) {
        return AppRole.values
            .map(
              (role) => PopupMenuItem<AppRole>(
                value: role,
                child: Row(
                  children: [
                    Icon(
                      role == AppRole.customer
                          ? Icons.shopping_bag
                          : Icons.store,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(role.label),
                  ],
                ),
              ),
            )
            .toList();
      },
    );
  }
}

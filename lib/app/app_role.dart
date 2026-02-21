enum AppRole { customer, supplier }

extension AppRoleLabel on AppRole {
  String get label {
    switch (this) {
      case AppRole.customer:
        return 'Customer';
      case AppRole.supplier:
        return 'Supplier';
    }
  }
}

import 'dart:io';

void main(List<String> args) {
  final root = args.isNotEmpty ? args.first : '.';

  final paths = <String>[
    'server/src/supplier/',
    'lib/pages/SupplierDashboardPage.dart',
    'lib/services/product_service.dart',
    'lib/models/product.dart',
  ];

  for (final relativePath in paths) {
    final fullPath = '$root/$relativePath'.replaceAll('\\', '/');
    final exists =
        FileSystemEntity.typeSync(fullPath) != FileSystemEntityType.notFound;
    stdout.writeln('${exists ? 'FOUND' : 'MISSING'}  $relativePath');
  }
}


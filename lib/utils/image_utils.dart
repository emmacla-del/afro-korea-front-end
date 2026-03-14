import '../services/api_service.dart';

String getImageUrl(String? relativePath) {
  if (relativePath == null || relativePath.isEmpty) return '';
  if (relativePath.startsWith('http')) return relativePath;
  // Remove leading slash if present
  final path = relativePath.startsWith('/')
      ? relativePath.substring(1)
      : relativePath;
  return '${ApiService.baseUrl}/$path';
}

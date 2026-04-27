import '../../domain/entities/product.dart';

class ProductLocalCache {
  List<Product>? _products;

  DateTime? _cachedAt;

  final Duration ttl = const Duration(minutes: 5);

  List<Product>? getIfValid() {
    if (_products == null || _cachedAt == null) return null;

    final now = DateTime.now();

    final isValid = now.difference(_cachedAt!) < ttl;

    return isValid ? _products : null;
  }

  void save(List<Product> products) {
    _products = products;

    _cachedAt = DateTime.now();
  }

  void clear() {
    _products = null;
    _cachedAt = null;
  }
}

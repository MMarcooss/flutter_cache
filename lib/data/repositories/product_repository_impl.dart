import 'dart:async';
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';
import '../datasources/product_remote_datasource.dart';
import '../datasources/product_memory_cache.dart';
import '../datasources/product_local_cache.dart';

class ProductRepositoryImpl implements ProductRepository {
  final ProductRemoteDatasource api;
  final ProductMemoryCache memoryCache;
  final ProductLocalCache localCache;

  ProductRepositoryImpl({
    required this.api,
    required this.memoryCache,
    required this.localCache,
  });

  @override
  Future<List<Product>> getProducts() async {
    final memory = memoryCache.getIfValid();
    if (memory != null) return memory;

    final local = await localCache.getProducts();

    if (local.isEmpty) {
      final remote = await api.fetchProducts();
      await localCache.save(remote);
      memoryCache.save(remote);
      return remote;
    }

    unawaited(() async {
      final remote = await api.fetchProducts();
      await localCache.save(remote);
      memoryCache.save(remote);
    }());

    return local;
  }
}

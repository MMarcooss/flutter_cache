import '../../domain/entities/product.dart';
import 'product_detail_page.dart';
import 'package:flutter/material.dart';
import '../../data/datasources/product_remote_datasource.dart';
import '../../data/datasources/product_memory_cache.dart';
import '../../data/datasources/product_local_cache.dart';
import '../../data/repositories/product_repository_impl.dart';
import '../../domain/repositories/product_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  bool isLoading = false;
  String? errorMessage;
  List<Product> products = [];
  late ProductRepository _repository;
  bool _repositoryReady = false;

  @override
  void initState() {
    super.initState();
    _initRepository();
  }

  Future<void> _initRepository() async {
    final prefs = await SharedPreferences.getInstance();
    _repository = ProductRepositoryImpl(
      api: ProductRemoteDatasource(),
      memoryCache: ProductMemoryCache(),
      localCache: ProductLocalCache(prefs),
    );
    _repositoryReady = true;
    await loadProducts();
  }

  Future<void> loadProducts() async {
    if (!_repositoryReady) return;
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      products = await _repository.getProducts();
      setState(() {});
    } catch (e) {
      setState(() {
        errorMessage = 'Falha ao carregar produtos: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> openDetails(Product product) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailPage(product: product)),
    );

    // PROBLEMA INTENCIONAL:
    // Ao voltar da tela de detalhes, refaz a chamada remota inteira.
    // Isso piora latência, desperdiça rede e recria toda a experiência.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo Problemático'),
        actions: [
          IconButton(onPressed: loadProducts, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (isLoading) {
            // PROBLEMA INTENCIONAL:
            // Loading bloqueia a tela inteira, mesmo quando já poderia haver conteúdo.
            return const Center(child: CircularProgressIndicator());
          }

          if (errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: loadProducts,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            itemCount: products.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final product = products[index];

              return ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: product.thumbnail,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 72,
                      height: 72,
                      color: Colors.grey.shade200,
                      child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 72,
                      height: 72,
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.broken_image),
                    ),
                  ),
                ),
                title: Text(
                  product.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${product.category} • R\$ ${product.price.toStringAsFixed(2)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => openDetails(product),
              );
            },
          );
        },
      ),
    );
  }
}

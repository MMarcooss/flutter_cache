import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product_model.dart';

class ProductLocalCache {
  static const String productsKey = 'cached_products';
  static const String timestampKey = 'cached_products_time';

  final SharedPreferences prefs;

  ProductLocalCache(this.prefs);

  Future<void> save(List<ProductModel> products) async {
    final encoded = products.map((p) => jsonEncode(p.toMap())).toList();

    await prefs.setStringList(productsKey, encoded);
    await prefs.setString(
      timestampKey,
      DateTime.now().toIso8601String(),
    );
  }

  Future<List<ProductModel>> getProducts() async {
    final saved = prefs.getStringList(productsKey) ?? [];
    return saved.map((item) => ProductModel.fromMap(jsonDecode(item))).toList();
  }

  DateTime? getCachedAt() {
    final value = prefs.getString(timestampKey);
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  Future<void> clear() async {
    await prefs.remove(productsKey);
    await prefs.remove(timestampKey);
  }
}

Future<void> loadProducts() async {
  setState(() {
    isLoading = true;
    errorMessage = null;
  });

  try {
    // PROBLEMA INTENCIONAL:
    // A UI acessa a API diretamente e concentra regras de infraestrutura.
    // Isso dificulta teste, manutenção e reaproveitamento.

    // PROBLEMA INTENCIONAL:
    // Latência artificial para que os alunos percebam o impacto do loading.
    await Future.delayed(const Duration(seconds: 2));

    final response = await http.get(
      Uri.parse('https://dummyjson.com/products?limit=30'),
    );

    if (response.statusCode != 200) {
      throw Exception('Erro ao buscar produtos');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final rawProducts = data['products'] as List<dynamic>;

    setState(() {
      products = rawProducts
          .map((item) => Product.fromMap(item as Map<String, dynamic>))
          .toList();
    });
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

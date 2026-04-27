# Análise e Evolução de Aplicação Flutter
**Disciplina:** Desenvolvimento para Dispositivos Móveis II  
**Projeto original:** https://github.com/jeffersonspeck/flutter_cache

---

## 1. Problemas Identificados no Projeto Original

O projeto original concentrava toda a lógica em um único arquivo `main.dart`, sem separação de responsabilidades, sem cache e com problemas intencionais de latência e responsividade.

### Problema 1 — UI acessando a rede diretamente

**Arquivo:** `main.dart`  
**Método:** `loadProducts()` → dentro do `try`

```dart
final response = await http.get(
  Uri.parse('https://dummyjson.com/products?limit=30'),
);
final data = jsonDecode(response.body) as Map<String, dynamic>;
```

**Impacto:** a interface realizava a requisição HTTP diretamente, misturando responsabilidades de UI e infraestrutura. Isso dificultava manutenção, testes e impossibilitava a implementação de cache.

---

### Problema 2 — Latência artificial bloqueando a interface

**Arquivo:** `main.dart`  
**Método:** `loadProducts()` → início do `try`

```dart
await Future.delayed(const Duration(seconds: 2));
```

**Impacto:** simulava uma API lenta, evidenciando que qualquer atraso sem feedback adequado degrada a experiência do usuário. A tela ficava travada por 2 segundos sem motivo real.

---

### Problema 3 — Loading bloqueando a tela inteira

**Arquivo:** `main.dart`  
**Método:** `build()` → início do `Builder`

```dart
if (isLoading) {
  return const Center(child: CircularProgressIndicator());
}
```

**Impacto:** mesmo que houvesse dados em cache, a tela ficava completamente bloqueada durante o carregamento. O usuário não via nenhum conteúdo até a requisição concluir.

---

### Problema 4 — Reload desnecessário ao voltar da tela de detalhe

**Arquivo:** `main.dart`  
**Método:** `openDetails()` → após o `Navigator.push`

```dart
Future<void> openDetails(Product product) async {
  await Navigator.push(...);
  await loadProducts(); // refazia toda a requisição remota
}
```

**Impacto:** ao voltar da tela de detalhe, o app refazia toda a busca na API, aumentando latência, consumindo rede desnecessariamente e destruindo a continuidade visual.

---

### Problema 5 — Imagens sem cache

**Arquivo:** `main.dart`  
**Método:** `build()` da `ProductListPage` → dentro do `ListTile` → `leading`

```dart
Image.network(product.thumbnail, ...)
```

**Arquivo:** `main.dart`  
**Método:** `build()` da `ProductDetailPage` → dentro do `PageView.builder`

```dart
Image.network(product.images[index], ...)
```

**Impacto:** as imagens eram baixadas novamente a cada exibição, sem placeholder durante o carregamento e sem política de reaproveitamento.

---

### Problema 6 — Ausência de separação arquitetural

**Arquivo:** `main.dart`  
**Localização:** arquivo inteiro

Todo o código estava em um único arquivo `main.dart`, incluindo modelo, páginas e lógica de negócio, tornando o projeto difícil de manter, testar e evoluir.

---

## 2. Mudanças Realizadas

### 2.1 Separação em camadas

O projeto foi reorganizado na seguinte estrutura:

```
lib/
├── data/
│   ├── datasources/
│   │   ├── product_remote_datasource.dart
│   │   ├── product_memory_cache.dart
│   │   └── product_local_cache.dart
│   ├── models/
│   │   └── product_model.dart
│   └── repositories/
│       └── product_repository_impl.dart
├── domain/
│   ├── entities/
│   │   └── product.dart
│   └── repositories/
│       └── product_repository.dart
├── presentation/
│   └── pages/
│       ├── product_list_page.dart
│       └── product_detail_page.dart
└── main.dart
```

---

### 2.2 Extração da lógica de rede para o datasource

**Arquivo:** `data/datasources/product_remote_datasource.dart`

A requisição HTTP foi movida para `ProductRemoteDatasource`, desacoplando a interface da infraestrutura.

```dart
class ProductRemoteDatasource {
  Future<List<ProductModel>> fetchProducts() async {
    final response = await http.get(
      Uri.parse('https://dummyjson.com/products?limit=30'),
    );
    ...
  }
}
```

---

### 2.3 Separação entre entidade e model

A classe `Product` foi separada em duas:

- `domain/entities/product.dart` → entidade pura, sem conhecimento de JSON
- `data/models/product_model.dart` → responsável por serializar e desserializar o JSON da API com `fromMap()` e `toMap()`

---

### 2.4 Implementação de cache em memória com TTL

**Arquivo:** `data/datasources/product_memory_cache.dart`

TTL (Time To Live) é o tempo máximo que um dado armazenado é considerado válido. Após esse tempo, o cache expira e o dado é buscado novamente. No projeto foi definido como 5 minutos.

```dart
class ProductMemoryCache {
  List<Product>? _products;
  DateTime? _cachedAt;
  final Duration ttl = const Duration(minutes: 5); // expira em 5 minutos

  List<Product>? getIfValid() {
    if (_products == null || _cachedAt == null) return null;
    final now = DateTime.now();
    final isValid = now.difference(_cachedAt!) < ttl;
    return isValid ? _products : null;
  }
  ...
}
```

**Resultado:** ao voltar da tela de detalhe, os dados são retornados instantaneamente da RAM sem nova requisição. Após 5 minutos o cache expira e uma nova busca é feita.

---

### 2.5 Implementação de cache local persistente

**Arquivo:** `data/datasources/product_local_cache.dart`

```dart
class ProductLocalCache {
  Future<void> save(List<ProductModel> products) async { ... }
  Future<List<ProductModel>> getProducts() async { ... }
}
```

**Resultado:** ao fechar e reabrir o app, os dados são carregados do disco sem necessidade de nova requisição à API.

---

### 2.6 Estratégia Stale-While-Revalidate no repository

**Arquivo:** `data/repositories/product_repository_impl.dart`

```dart
Future<List<Product>> getProducts() async {
  final memory = memoryCache.getIfValid();
  if (memory != null) return memory; // 1º memória

  final local = await localCache.getProducts();

  if (local.isEmpty) {
    final remote = await api.fetchProducts(); // 3º API (primeira vez)
    await localCache.save(remote);
    memoryCache.save(remote);
    return remote;
  }

  unawaited(() async {
    final remote = await api.fetchProducts(); // atualiza em segundo plano
    await localCache.save(remote);
    memoryCache.save(remote);
  }());

  return local; // 2º disco, retorna imediatamente
}
```

**Fluxo:**
1. tem na memória e ainda válido → retorna na hora
2. tem no disco → retorna do disco e atualiza a API em segundo plano
3. não tem nada → vai na API, salva nos dois caches e retorna

---

### 2.7 Cache de imagens com CachedNetworkImage

**Arquivo:** `presentation/pages/product_list_page.dart` → dentro do `ListTile` → `leading`  
**Arquivo:** `presentation/pages/product_detail_page.dart` → dentro do `PageView.builder`

```dart
CachedNetworkImage(
  imageUrl: product.thumbnail,
  placeholder: (context, url) => CircularProgressIndicator(),
  errorWidget: (context, url, error) => Icon(Icons.broken_image),
)
```

**Resultado:** imagens são baixadas uma única vez e reutilizadas, com placeholder durante o carregamento.

---

### 2.8 Remoção do reload desnecessário ao voltar da tela de detalhe

**Arquivo:** `presentation/pages/product_list_page.dart`  
**Método:** `openDetails()`

```dart
// ANTES
Future<void> openDetails(Product product) async {
  await Navigator.push(...);
  await loadProducts(); // problema removido
}

// DEPOIS
Future<void> openDetails(Product product) async {
  await Navigator.push(...);
  // cache em memória resolve sem nova requisição
}
```

---

## 3. Justificativa Técnica

| Problema | Arquivo original | Mudança | Justificativa |
|---|---|---|---|
| UI acessando a rede | `main.dart` → `loadProducts()` | `ProductRemoteDatasource` | Separa responsabilidades, facilita manutenção e permite cache |
| Latência artificial | `main.dart` → `loadProducts()` | Removida | Era um problema intencional para evidenciar o impacto do loading |
| Loading bloqueando tela | `main.dart` → `build()` | Stale-While-Revalidate | Mostra cache imediatamente enquanto atualiza em segundo plano |
| Reload ao voltar | `main.dart` → `openDetails()` | Cache em memória | Dados já estão na RAM, sem necessidade de nova requisição |
| Imagens sem cache | `main.dart` → `build()` | CachedNetworkImage | Evita downloads repetidos e melhora fluidez da lista |
| Sem separação arquitetural | `main.dart` inteiro | Camadas domain/data/presentation | Facilita manutenção, teste e evolução do projeto |

---

## 4. Resultado

- Navegação entre telas instantânea após primeiro carregamento
- Imagens com placeholder e sem piscadas
- App funciona com dados anteriores mesmo após ser fechado e reaberto
- Interface não trava durante atualizações em segundo plano
- Código organizado em camadas com responsabilidades bem definidas

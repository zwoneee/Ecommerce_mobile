  // lib/screens/product_list_screen.dart
  import 'package:flutter/material.dart';
  import 'package:provider/provider.dart';

  import '../services/api_service.dart';
  import '../models/product.dart';
  import 'product_detail_screen.dart';
  import '../providers/auth_provider.dart';
  import '../providers/cart_provider.dart';
  import 'cart_screen.dart';

  class ProductListScreen extends StatefulWidget {
    const ProductListScreen({super.key});

    @override
    State<ProductListScreen> createState() => _ProductListScreenState();
  }

  class _ProductListScreenState extends State<ProductListScreen> {
    final ScrollController _scrollController = ScrollController();
    final TextEditingController _searchController = TextEditingController();

    bool _loading = true;
    bool _loadingMore = false;
    bool _hasMore = true;
    int _page = 1;
    final int _pageSize = 20;
    final List<Product> _products = [];
    final List<Product> _allProducts = [];
    String _searchQuery = '';
    List<Map<String, dynamic>> _categories = [];
    bool _loadingCategories = false;

    @override
    void initState() {
      super.initState();
      WidgetsBinding.instance!.addPostFrameCallback((_) {
        _fetch(page: 1);
        _fetchCategories();
      });

      _scrollController.addListener(() {
        if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
          if (!_loadingMore && !_loading && _hasMore && _searchQuery.isEmpty) {
            _loadMore();
          }
        }
      });
    }

    @override
    void dispose() {
      _scrollController.dispose();
      _searchController.dispose();
      super.dispose();
    }

    Future<void> _fetchCategories() async {
      setState(() => _loadingCategories = true);
      try {
        final api = Provider.of<ApiService>(context, listen: false);
        final data = await api.fetchCategories();

        if (mounted && data != null) {
          final List<Map<String, dynamic>> cats = [];
          if (data is List) {
            for (final item in data) {
              if (item is Map && item['id'] != null && item['name'] != null) {
                cats.add({'id': item['id'], 'name': item['name'].toString()});
              }
            }
          }
          setState(() => _categories = cats);
        }
      } catch (e) {
        print('Error fetching categories: $e');
      } finally {
        if (mounted) setState(() => _loadingCategories = false);
      }
    }


    Future<void> _fetch({int page = 1, bool showMessageOnError = true}) async {
      if (mounted) setState(() {
        if (page == 1) _loading = true;
        else _loadingMore = true;
      });

      try {
        final api = Provider.of<ApiService>(context, listen: false);
        final data = await api.fetchProducts(page: page, pageSize: _pageSize);
        print('fetchProducts response: $data');

        final raw = data['products'];
        final List<Product> list = [];

        if (raw != null && raw is List) {
          for (final e in raw) {
            try {
              if (e is Map) {
                list.add(Product.fromJson(Map<String, dynamic>.from(e)));
              } else if (e is Map<String, dynamic>) {
                list.add(Product.fromJson(e));
              }
            } catch (itemEx) {
              print('product parse error: $itemEx for item $e');
            }
          }
        }

        if (mounted) {
          if (page == 1) {
            _products.clear();
            _allProducts.clear();
            _products.addAll(list);
            _allProducts.addAll(list);
          } else {
            _products.addAll(list);
            _allProducts.addAll(list);
          }

          _page = page;
          _hasMore = list.length >= _pageSize;
        }
      } catch (e, st) {
        print('Error fetching products: $e\n$st');
        if (showMessageOnError && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi tải sản phẩm: $e'),
              backgroundColor: Colors.red.shade400,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } finally {
        if (mounted) setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }

    void _performSearch(String query) {
      setState(() {
        _searchQuery = query.toLowerCase();
        if (_searchQuery.isEmpty) {
          _products.clear();
          _products.addAll(_allProducts);
        } else {
          _products.clear();
          _products.addAll(
            _allProducts.where((p) => p.name.toLowerCase().contains(_searchQuery)).toList(),
          );
        }
      });
    }

    Future<void> _loadMore() async {
      if (!_hasMore) return;
      final next = _page + 1;
      await _fetch(page: next, showMessageOnError: false);
    }

    Future<void> _refresh() async {
      _searchController.clear();
      _searchQuery = '';
      await _fetch(page: 1);
    }

    void _showCategoryDialog() {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => Container(
          margin: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Text(
                      'Danh mục',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (_loadingCategories)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                )
              else if (_categories.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Không có danh mục'),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade50,
                        child: Icon(Icons.category_outlined, color: Colors.blue.shade700, size: 20),
                      ),
                      title: Text(category['name']),
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _products.clear();
                          _products.addAll(
                            _allProducts.where((p) => p.categoryId == category['id']).toList(),
                          );
                        });
                      },
                    );
                  },
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    }

    @override
    Widget build(BuildContext context) {
      final cart = Provider.of<CartProvider>(context);
      final auth = Provider.of<AuthProvider>(context);

      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          leading: IconButton(
            onPressed: _showCategoryDialog,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.menu, color: Colors.blue.shade700, size: 24),
            ),
          ),
          title: const Text(
            'Trang chủ',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            // Search button
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                onPressed: () {
                  showSearch(
                    context: context,
                    delegate: ProductSearchDelegate(
                      products: _allProducts,
                      onSearch: _performSearch,
                    ),
                  );
                },
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.search, color: Colors.grey.shade700, size: 24),
                ),
              ),
            ),
            // Cart button with badge
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CartScreen()),
                ),
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.shopping_bag_outlined, color: Colors.blue.shade700, size: 24),
                    ),
                    if (cart.items.isNotEmpty)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                          child: Text(
                            cart.items.length.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Auth button
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: auth.isAuthenticated
                  ? PopupMenuButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.person_outline, color: Colors.grey.shade700, size: 24),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: Row(
                      children: [
                        Icon(Icons.logout, size: 20, color: Colors.red.shade400),
                        const SizedBox(width: 12),
                        const Text('Đăng xuất'),
                      ],
                    ),
                    onTap: () async {
                      await Future.delayed(Duration.zero);
                      await auth.logout();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Đã đăng xuất'),
                            backgroundColor: Colors.green.shade400,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      }
                      setState(() {});
                    },
                  ),
                ],
              )
                  : TextButton.icon(
                onPressed: () => Navigator.of(context).pushNamed('/login'),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.login, color: Colors.white, size: 20),
                label: const Text('Login', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
        body: _loading && _products.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.blue.shade600),
              const SizedBox(height: 16),
              Text(
                'Đang tải sản phẩm mới nhất...',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
            ],
          ),
        )
            : RefreshIndicator(
          onRefresh: _refresh,
          color: Colors.blue.shade600,
          child: _products.isEmpty
              ? ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 120),
              Icon(Icons.search_off, size: 80, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  _searchQuery.isEmpty ? 'Không có sản phẩm' : 'Không tìm thấy sản phẩm',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                ),
              ),
            ],
          )
              : GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _products.length + (_loadingMore ? 2 : 0),
            itemBuilder: (context, index) {
              if (index >= _products.length) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.blue.shade600,
                    ),
                  ),
                );
              }
              final p = _products[index];
              return _buildProductCard(p);
            },
          ),
        ),
      );
    }

    Widget _buildProductCard(Product p) {
      return GestureDetector(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: p.id)),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product image
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: p.thumbnailUrl.isNotEmpty
                        ? Image.network(
                      p.thumbnailUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Icon(Icons.image_not_supported, color: Colors.grey.shade400, size: 40),
                      ),
                    )
                        : Center(
                      child: Icon(Icons.image_outlined, color: Colors.grey.shade400, size: 40),
                    ),
                  ),
                ),
              ),
              // Product info
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '\$${p.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(Icons.arrow_forward_ios, size: 12, color: Colors.blue.shade700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  // Search Delegate
  // lib/screens/product_list_screen.dart
  class ProductSearchDelegate extends SearchDelegate<Product?> {
    final List<Product> products;
    final Function(String) onSearch;

    ProductSearchDelegate({required this.products, required this.onSearch});

    @override
    String get searchFieldLabel => 'Tìm kiếm sản phẩm...';

    @override
    List<Widget> buildActions(BuildContext context) {
      return [
        if (query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              query = '';
              showSuggestions(context);
            },
          ),
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            // Khi nhấn Search, thực hiện tìm kiếm và đóng keyboard
            onSearch(query);
            close(context, null);
          },
        ),
      ];
    }

    @override
    Widget buildLeading(BuildContext context) {
      return IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );
    }

    @override
    Widget buildResults(BuildContext context) {
      // Gọi lại onSearch khi người dùng nhấn nút "search"
      onSearch(query);
      return const SizedBox.shrink(); // Không cần hiển thị gì ở đây
    }

    @override
    Widget buildSuggestions(BuildContext context) {
      // Gợi ý sản phẩm khi đang nhập
      final suggestions = query.isEmpty
          ? products.take(10).toList()
          : products.where((p) => p.name.toLowerCase().contains(query.toLowerCase())).take(10).toList();

      return ListView.builder(
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          final product = suggestions[index];
          return ListTile(
            leading: product.thumbnailUrl.isNotEmpty
                ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                product.thumbnailUrl,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 50,
                  height: 50,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.image),
                ),
              ),
            )
                : Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.image),
            ),
            title: Text(product.name),
            subtitle: Text('\$${product.price.toStringAsFixed(2)}'),
            onTap: () {
              query = product.name;
              onSearch(query);
              close(context, product);
            },
          );
        },
      );
    }
  }

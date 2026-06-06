import 'package:flutter/material.dart';
import 'dart:math' as math;

class PaginationController extends ChangeNotifier {
  int _currentPage = 1;
  final int _itemsPerPage;
  int _totalItems = 0;

  PaginationController({int itemsPerPage = 10}) : _itemsPerPage = itemsPerPage;

  int get currentPage => _currentPage;
  int get itemsPerPage => _itemsPerPage;
  int get totalItems => _totalItems;
  int get totalPages => _totalItems == 0 ? 0 : ((_totalItems + _itemsPerPage - 1) ~/ _itemsPerPage);
  bool get hasNextPage => _currentPage < totalPages;
  bool get hasPreviousPage => _currentPage > 1;

  void setTotalItems(int total) {
    _totalItems = total;
    notifyListeners();
  }

  void nextPage() {
    if (hasNextPage) {
      _currentPage++;
      notifyListeners();
    }
  }

  void previousPage() {
    if (hasPreviousPage) {
      _currentPage--;
      notifyListeners();
    }
  }

  void goToPage(int page) {
    if (page > 0 && page <= totalPages) {
      _currentPage = page;
      notifyListeners();
    }
  }

  void reset() {
    _currentPage = 1;
    notifyListeners();
  }

  List<T> getPageItems<T>(List<T> allItems) {
    if (allItems.isEmpty) return <T>[];
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    if (startIndex >= allItems.length) return <T>[];
    final endIndex = math.min(startIndex + _itemsPerPage, allItems.length);
    return allItems.sublist(startIndex, endIndex);
  }
}

/// لاحقة لإضافة Pagination إلى قائمة
class PaginatedListView extends StatefulWidget {
  final List<Widget> Function(List<dynamic>) itemBuilder;
  final List<dynamic> items;
  final int itemsPerPage;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;

  const PaginatedListView({
    super.key,
    required this.itemBuilder,
    required this.items,
    this.itemsPerPage = 10,
    this.padding,
    this.physics,
  });

  @override
  State<PaginatedListView> createState() => _PaginatedListViewState();
}

class _PaginatedListViewState extends State<PaginatedListView> {
  late PaginationController _paginationController;

  @override
  void initState() {
    super.initState();
    _paginationController = PaginationController(
      itemsPerPage: widget.itemsPerPage,
    );
    _paginationController.setTotalItems(widget.items.length);
  }

  @override
  void dispose() {
    _paginationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageItems = _paginationController.getPageItems(widget.items);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: widget.padding,
            physics: widget.physics,
            children: widget.itemBuilder(pageItems),
          ),
        ),
        if (_paginationController.totalPages > 1) _buildPaginationControls(),
      ],
    );
  }

  Widget _buildPaginationControls() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _paginationController.hasPreviousPage
                ? () {
                    _paginationController.previousPage();
                    setState(() {});
                  }
                : null,
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_paginationController.totalPages, (
                index,
              ) {
                final page = index + 1;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () {
                      _paginationController.goToPage(page);
                      setState(() {});
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _paginationController.currentPage == page
                            ? Colors.blue.shade700
                            : Colors.white,
                        border: Border.all(
                          color: _paginationController.currentPage == page
                              ? Colors.blue.shade700
                              : Colors.grey.shade300,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          page.toString(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _paginationController.currentPage == page
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _paginationController.hasNextPage
                ? () {
                    _paginationController.nextPage();
                    setState(() {});
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

/// Cache service لتحسين الأداء
class CacheService {
  static final CacheService _instance = CacheService._internal();
  final Map<String, _CacheEntry> _cache = {};
  late Duration _defaultDuration;

  factory CacheService({Duration duration = const Duration(minutes: 5)}) {
    _instance._defaultDuration = duration;
    return _instance;
  }

  CacheService._internal();

  /// حفظ قيمة مع مدة الحفظ
  void set<T>(String key, T value, {Duration? duration}) {
    _cache[key] = _CacheEntry(
      value: value,
      expiresAt: DateTime.now().add(duration ?? _defaultDuration),
    );
  }

  /// الحصول على قيمة
  T? get<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;

    if (DateTime.now().isAfter(entry.expiresAt)) {
      _cache.remove(key);
      return null;
    }

    return entry.value as T?;
  }

  /// التحقق من وجود مفتاح صالح
  bool has(String key) {
    final entry = _cache[key];
    if (entry == null) return false;

    if (DateTime.now().isAfter(entry.expiresAt)) {
      _cache.remove(key);
      return false;
    }

    return true;
  }

  /// حذف مفتاح محدد
  void remove(String key) {
    _cache.remove(key);
  }

  /// حذف جميع المفاتيح المنتهية الصلاحية
  void cleanup() {
    final now = DateTime.now();
    _cache.removeWhere((key, entry) => now.isAfter(entry.expiresAt));
  }

  /// حذف كل شيء
  void clear() {
    _cache.clear();
  }

  int get size => _cache.length;
}

class _CacheEntry {
  final dynamic value;
  final DateTime expiresAt;

  _CacheEntry({required this.value, required this.expiresAt});
}

/// استخراج صورة محسنة لتقليل حجم الذاكرة
class OptimizedCacheImage extends StatelessWidget {
  final String? imageUrl;
  final double width;
  final double height;
  final BoxFit fit;
  final String? placeholder;

  const OptimizedCacheImage({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: Colors.grey[300],
        child: Icon(Icons.image_not_supported, color: Colors.grey[600]),
      );
    }

    // يمكن استبدال هذا بـ cached_network_image إذا أضفت المكتبة
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text('IMG', style: TextStyle(color: Colors.grey[600])),
      ),
    );
  }
}

/// تحسينات الأداء: قائمة محسنة مع LazyLoading
class OptimizedListView extends StatefulWidget {
  final List<Widget> items;
  final int itemsPerBatch;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry? padding;

  const OptimizedListView({
    super.key,
    required this.items,
    this.itemsPerBatch = 20,
    this.physics,
    this.padding,
  });

  @override
  State<OptimizedListView> createState() => _OptimizedListViewState();
}

class _OptimizedListViewState extends State<OptimizedListView> {
  late int _itemsToShow;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _itemsToShow = widget.itemsPerBatch;
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      if (_itemsToShow < widget.items.length) {
        setState(() {
          _itemsToShow += widget.itemsPerBatch;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayed = math.min(_itemsToShow, widget.items.length);
    final hasMore = displayed < widget.items.length;

    return ListView.builder(
      controller: _scrollController,
      physics: widget.physics,
      padding: widget.padding,
      itemCount: displayed + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < displayed) {
          return widget.items[index];
        } else if (hasMore) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: CircularProgressIndicator(color: Colors.blue.shade700),
            ),
          );
        } else {
          return const SizedBox.shrink();
        }
      },
    );
  }
}

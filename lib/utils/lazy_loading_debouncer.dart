import 'dart:async';
import 'package:flutter/material.dart';

/// Search Debouncer for Real-Time Search
/// 
/// Debounces search input to avoid excessive API calls
/// 
/// Usage:
/// ```dart
/// final _searchDebouncer = SearchDebouncer(
///   onSearch: (query) => _controller.searchEmployees(query),
///   delay: Duration(milliseconds: 300),
/// );
/// 
/// // In TextField:
/// onChanged: (value) => _searchDebouncer.run(value),
/// 
/// // Don't forget to dispose:
/// @override
/// void dispose() {
///   _searchDebouncer.dispose();
///   super.dispose();
/// }
/// ```
class SearchDebouncer {
  final Function(String) onSearch;
  final Duration delay;
  Timer? _timer;
  String _lastQuery = '';

  SearchDebouncer({
    required this.onSearch,
    this.delay = const Duration(milliseconds: 300),
  });

  /// Run debounced search
  void run(String query) {
    _lastQuery = query;

    // Cancel previous timer
    _timer?.cancel();

    // Create new timer
    _timer = Timer(delay, () {
      if (query.isNotEmpty) {
        onSearch(query);
      }
    });
  }

  /// Dispose debouncer
  void dispose() {
    _timer?.cancel();
  }

  /// Clear search
  void clear() {
    _timer?.cancel();
    _lastQuery = '';
  }

  /// Get last query
  String getLastQuery() => _lastQuery;
}

/// Lazy List Loader for Pagination
/// 
/// Handles automatic pagination on scroll
/// 
/// Usage:
/// ```dart
/// final _lazyLoader = LazyListLoader(
///   initialPage: 1,
///   pageSize: 20,
///   onLoadMore: (page) => _controller.loadEmployees(page: page),
/// );
/// 
/// // In ListView.builder:
/// itemCount: _lazyLoader.totalItems,
/// onLoad: () => _lazyLoader.loadMoreIfNeeded(),
/// ```
class LazyListLoader {
  int _currentPage;
  final int pageSize;
  final Future<int> Function(int) onLoadMore;
  bool _isLoading = false;
  int _totalItems = 0;

  LazyListLoader({
    required int initialPage,
    required this.pageSize,
    required this.onLoadMore,
  }) : _currentPage = initialPage;

  /// Check if should load more data
  bool shouldLoadMore(int currentIndex) {
    return currentIndex >= (_totalItems - pageSize);
  }

  /// Load more data if needed
  Future<void> loadMoreIfNeeded(int currentIndex) async {
    if (shouldLoadMore(currentIndex) && !_isLoading) {
      await loadMore();
    }
  }

  /// Load next page
  Future<void> loadMore() async {
    if (_isLoading) return;

    _isLoading = true;
    try {
      _totalItems = await onLoadMore(_currentPage);
      _currentPage++;
    } finally {
      _isLoading = false;
    }
  }

  /// Reset loader
  void reset() {
    _currentPage = 1;
    _totalItems = 0;
    _isLoading = false;
  }

  /// Getters
  int get currentPage => _currentPage;
  bool get isLoading => _isLoading;
  int get totalItems => _totalItems;
}

/// Infinite Scroll Listener
/// 
/// ListView wrapper that automatically loads more data on scroll
/// 
/// Usage:
/// ```dart
/// InfiniteScrollListener(
///   itemCount: items.length,
///   itemBuilder: (context, index) => ItemTile(items[index]),
///   onLoadMore: () => _controller.loadMore(),
///   threshold: 5, // Load when 5 items from end
/// )
/// ```
class InfiniteScrollListener extends StatefulWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final Future<void> Function() onLoadMore;
  final int threshold;
  final ScrollController? scrollController;

  const InfiniteScrollListener({
    Key? key,
    required this.itemCount,
    required this.itemBuilder,
    required this.onLoadMore,
    this.threshold = 5,
    this.scrollController,
  }) : super(key: key);

  @override
  State<InfiniteScrollListener> createState() => _InfiniteScrollListenerState();
}

class _InfiniteScrollListenerState extends State<InfiniteScrollListener> {
  late ScrollController _scrollController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    if (widget.scrollController == null) {
      _scrollController.dispose();
    } else {
      _scrollController.removeListener(_onScroll);
    }
    super.dispose();
  }

  void _onScroll() {
    if (_isLoading) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    final loadThreshold = maxScroll * 0.8;

    if (currentScroll > loadThreshold) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      await widget.onLoadMore();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: widget.itemCount + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == widget.itemCount) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        return widget.itemBuilder(context, index);
      },
    );
  }
}

/// Debounced Text Field Widget
/// 
/// TextField with built-in debouncing for search
/// 
/// Usage:
/// ```dart
/// DebouncedSearchField(
///   onSearch: (query) => _controller.search(query),
///   hintText: 'Search employees...',
///   debounceDelay: Duration(milliseconds: 300),
/// )
/// ```
class DebouncedSearchField extends StatefulWidget {
  final Function(String) onSearch;
  final String hintText;
  final Duration debounceDelay;
  final TextEditingController? controller;
  final InputDecoration? decoration;
  final int minCharsToSearch;

  const DebouncedSearchField({
    Key? key,
    required this.onSearch,
    this.hintText = 'Search...',
    this.debounceDelay = const Duration(milliseconds: 300),
    this.controller,
    this.decoration,
    this.minCharsToSearch = 2,
  }) : super(key: key);

  @override
  State<DebouncedSearchField> createState() => _DebouncedSearchFieldState();
}

class _DebouncedSearchFieldState extends State<DebouncedSearchField> {
  late TextEditingController _controller;
  late SearchDebouncer _debouncer;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _debouncer = SearchDebouncer(
      onSearch: (query) {
        if (query.length >= widget.minCharsToSearch) {
          widget.onSearch(query);
        }
      },
      delay: widget.debounceDelay,
    );
  }

  @override
  void dispose() {
    _debouncer.dispose();
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: (value) => _debouncer.run(value),
      decoration: widget.decoration ??
          InputDecoration(
            hintText: widget.hintText,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      _debouncer.clear();
                      widget.onSearch('');
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
    );
  }
}

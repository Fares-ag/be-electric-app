import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class PerformanceService {

  /// Compress image to reduce file size
  static Future<String> compressImage(
    String imagePath, {
    int quality = 85,
    int maxWidth = 1920,
    int maxHeight = 1080,
  }) async {
    try {
      // Read the image file
      final imageFile = File(imagePath);
      final imageBytes = await imageFile.readAsBytes();

      // Decode the image
      final originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) {
        throw Exception('Failed to decode image');
      }

      // Calculate new dimensions while maintaining aspect ratio
      var newWidth = originalImage.width;
      var newHeight = originalImage.height;

      if (originalImage.width > maxWidth || originalImage.height > maxHeight) {
        final aspectRatio = originalImage.width / originalImage.height;

        if (originalImage.width > originalImage.height) {
          newWidth = maxWidth;
          newHeight = (maxWidth / aspectRatio).round();
        } else {
          newHeight = maxHeight;
          newWidth = (maxHeight * aspectRatio).round();
        }
      }

      // Resize the image
      final resizedImage = img.copyResize(
        originalImage,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear,
      );

      // Encode the image with compression
      final List<int> compressedBytes = img.encodeJpg(
        resizedImage,
        quality: quality,
      );

      // Save compressed image
      final tempDir = await getTemporaryDirectory();
      final compressedPath =
          '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final compressedFile = File(compressedPath);
      await compressedFile.writeAsBytes(compressedBytes);

      return compressedPath;
    } catch (e, st) {
      throw Exception('Failed to compress image: $e');
    }
  }

  /// Optimize database queries with pagination
  static Map<String, dynamic> paginateQuery({
    required int page,
    required int pageSize,
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
  }) {
    final offset = (page - 1) * pageSize;

    var query = '';
    final args = <dynamic>[];

    if (where != null) {
      query += ' WHERE $where';
      if (whereArgs != null) {
        args.addAll(whereArgs);
      }
    }

    if (orderBy != null) {
      query += ' ORDER BY $orderBy';
    }

    query += ' LIMIT $pageSize OFFSET $offset';

    return {
      'query': query,
      'args': args,
    };
  }

  /// Debounce function calls to prevent excessive API calls
  static final Map<String, Timer> _debounceTimers = {};

  static void debounce(
    String key,
    VoidCallback callback, {
    Duration delay = const Duration(milliseconds: 500),
  }) {
    _debounceTimers[key]?.cancel();
    _debounceTimers[key] = Timer(delay, callback);
  }

  /// Throttle function calls to limit execution frequency
  static final Map<String, DateTime> _throttleTimestamps = {};

  static bool throttle(
    String key, {
    Duration interval = const Duration(seconds: 1),
  }) {
    final now = DateTime.now();
    final lastExecution = _throttleTimestamps[key];

    if (lastExecution == null || now.difference(lastExecution) >= interval) {
      _throttleTimestamps[key] = now;
      return true;
    }

    return false;
  }

  /// Cache data in memory for quick access
  static final Map<String, dynamic> _cache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};

  static void setCache(String key, dynamic value, {Duration? ttl}) {
    _cache[key] = value;
    _cacheTimestamps[key] = DateTime.now();

    if (ttl != null) {
      Timer(ttl, () => removeCache(key));
    }
  }

  static T? getCache<T>(String key, {Duration? maxAge}) {
    if (!_cache.containsKey(key)) return null;

    if (maxAge != null) {
      final timestamp = _cacheTimestamps[key];
      if (timestamp != null && DateTime.now().difference(timestamp) > maxAge) {
        removeCache(key);
        return null;
      }
    }

    return _cache[key] as T?;
  }

  static void removeCache(String key) {
    _cache.remove(key);
    _cacheTimestamps.remove(key);
  }

  static void clearCache() {
    _cache.clear();
    _cacheTimestamps.clear();
  }

  /// Lazy load images with placeholder
  static Widget buildLazyImage({
    required String imagePath,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) => FutureBuilder<File>(
      future: Future.value(File(imagePath)),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.existsSync()) {
          return Image.file(
            snapshot.data!,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error, stackTrace) => errorWidget ??
                  Container(
                    width: width,
                    height: height,
                    color: Colors.grey[300],
                    child: const Icon(Icons.broken_image),
                  ),
          );
        } else {
          return placeholder ??
              Container(
                width: width,
                height: height,
                color: Colors.grey[300],
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              );
        }
      },
    );

  /// Optimize list rendering with automatic pagination
  static Widget buildPaginatedList<T>({
    required Future<List<T>> Function(int page, int pageSize) fetchData,
    required Widget Function(T item, int index) itemBuilder,
    int pageSize = 20,
    Widget? loadingWidget,
    Widget? errorWidget,
    Widget? emptyWidget,
  }) => _PaginatedListWidget<T>(
      fetchData: fetchData,
      itemBuilder: itemBuilder,
      pageSize: pageSize,
      loadingWidget: loadingWidget,
      errorWidget: errorWidget,
      emptyWidget: emptyWidget,
    );

  /// Memory usage monitoring
  static void logMemoryUsage(String context) {
    // This would typically use platform-specific memory monitoring
    // For now, we'll just log the context
    debugPrint('Memory check at: $context');
  }

  /// Clean up resources
  static void cleanup() {
    // Cancel all debounce timers
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();

    // Clear cache
    clearCache();

    // Clear throttle timestamps
    _throttleTimestamps.clear();
  }
}

class _PaginatedListWidget<T> extends StatefulWidget {

  const _PaginatedListWidget({
    required this.fetchData,
    required this.itemBuilder,
    required this.pageSize,
    this.loadingWidget,
    this.errorWidget,
    this.emptyWidget,
  });
  final Future<List<T>> Function(int page, int pageSize) fetchData;
  final Widget Function(T item, int index) itemBuilder;
  final int pageSize;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  final Widget? emptyWidget;

  @override
  State<_PaginatedListWidget<T>> createState() =>
      _PaginatedListWidgetState<T>();
}

class _PaginatedListWidgetState<T> extends State<_PaginatedListWidget<T>> {
  final List<T> _items = [];
  int _currentPage = 1;
  bool _isLoading = false;
  bool _hasError = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final newItems = await widget.fetchData(_currentPage, widget.pageSize);

      setState(() {
        _items.addAll(newItems);
        _currentPage++;
        _hasMore = newItems.length == widget.pageSize;
        _isLoading = false;
      });
    } catch (e, st) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty && _isLoading) {
      return widget.loadingWidget ??
          const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty && _hasError) {
      return widget.errorWidget ??
          const Center(child: Text('Failed to load data'));
    }

    if (_items.isEmpty) {
      return widget.emptyWidget ??
          const Center(child: Text('No data available'));
    }

    return ListView.builder(
      itemCount: _items.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          // Load more trigger
          if (_hasMore && !_isLoading) {
            _loadData();
          }
          return _isLoading
              ? const Center(child: CircularProgressIndicator())
              : const SizedBox.shrink();
        }

        return widget.itemBuilder(_items[index], index);
      },
    );
  }
}

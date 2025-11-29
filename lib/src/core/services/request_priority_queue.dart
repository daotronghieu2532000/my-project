import 'dart:async';
import 'dart:collection';
import 'package:http/http.dart' as http;

/// Request Priority Queue - Giống Shopee/Lazada
/// 
/// Chức năng:
/// 1. Giới hạn số requests đồng thời (max 6-8)
/// 2. Priority queue: Request quan trọng chạy trước
/// 3. Tránh network congestion
class RequestPriorityQueue {
  static final RequestPriorityQueue _instance = RequestPriorityQueue._internal();
  factory RequestPriorityQueue() => _instance;
  RequestPriorityQueue._internal();

  // Giới hạn số request đồng thời (Shopee: 6-8, chúng ta dùng 6)
  static const int maxConcurrentRequests = 6;
  
  // Track số request đang chạy
  int _currentRequests = 0;
  
  // Priority queue
  final Queue<_RequestTask> _queue = Queue<_RequestTask>();
  
  /// Execute HTTP request với priority
  /// 
  /// Priority levels:
  /// - 2: URGENT (UI block, cần ngay)
  /// - 1: HIGH (Visible content)
  /// - 0: NORMAL (Background, prefetch)
  Future<http.Response?> execute(
    Future<http.Response?> Function() request, {
    int priority = 0,
    Duration? timeout,
  }) async {
    final completer = Completer<http.Response?>();
    
    final task = _RequestTask(
      request: request,
      priority: priority,
      completer: completer,
      timeout: timeout,
    );
    
    // Nếu chưa đạt max, chạy ngay
    if (_currentRequests < maxConcurrentRequests) {
      _executeTask(task);
    } else {
      // Thêm vào queue
      _queue.add(task);
      // Sort theo priority (high trước)
      _resortQueue();
    }
    
    return completer.future;
  }
  
  void _resortQueue() {
    final list = _queue.toList();
    list.sort((a, b) => b.priority.compareTo(a.priority));
    _queue.clear();
    _queue.addAll(list);
  }
  
  void _executeTask(_RequestTask task) async {
    _currentRequests++;
    
    try {
      final response = await (task.timeout != null
          ? task.request().timeout(task.timeout!)
          : task.request());
      task.completer.complete(response);
    } catch (e) {
      task.completer.completeError(e);
    } finally {
      _currentRequests--;
      
      // Execute next task in queue
      if (_queue.isNotEmpty) {
        final nextTask = _queue.removeFirst();
        _executeTask(nextTask);
      }
    }
  }
  
  /// Clear queue (khi cần cancel all)
  void clearQueue() {
    for (final task in _queue) {
      task.completer.completeError('Request cancelled');
    }
    _queue.clear();
  }
  
  /// Get stats
  Map<String, int> getStats() {
    return {
      'currentRequests': _currentRequests,
      'queueLength': _queue.length,
    };
  }
}

class _RequestTask {
  final Future<http.Response?> Function() request;
  final int priority;
  final Completer<http.Response?> completer;
  final Duration? timeout;
  
  _RequestTask({
    required this.request,
    required this.priority,
    required this.completer,
    this.timeout,
  });
}

/// Priority levels
class RequestPriority {
  static const int urgent = 2; // UI block
  static const int high = 1;   // Visible content
  static const int normal = 0; // Background
}


import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

/// Hard limits applied to every incoming frame (protects against memory-exhaustion peers).
class FrameLimits {
  static const int maxHeaderBytes = 64 * 1024;
  static const int maxPayloadBytes = 16 * 1024 * 1024;
  const FrameLimits._();
}

class FrameFormatException implements Exception {
  final String message;
  const FrameFormatException(this.message);
  @override
  String toString() => 'FrameFormatException: $message';
}

class WireFrame {
  final Map<String, dynamic> header;
  final Uint8List payload;
  const WireFrame(this.header, this.payload);
}

/// Incremental parser for `[u32 headerLen][header JSON][payload]` frames.
///
/// Linear time: bytes are appended to one growable buffer and consumed by advancing
/// a read offset, so a 1 MB chunk arriving in many socket packets is never re-copied
/// per packet (the previous implementation copied the whole buffer on every loop).
class FrameReader {
  Uint8List _buf = Uint8List(128 * 1024);
  int _start = 0;
  int _end = 0;

  Map<String, dynamic>? _pendingHeader;
  int _pendingHeaderLen = 0;
  int _pendingPayloadLen = 0;

  int get bufferedBytes => _end - _start;

  void add(List<int> data) {
    if (data.isEmpty) return;
    final live = _end - _start;
    if (_end + data.length > _buf.length) {
      var cap = _buf.length;
      final required = live + data.length;
      while (cap < required) {
        cap *= 2;
      }
      if (cap != _buf.length) {
        final grown = Uint8List(cap);
        grown.setRange(0, live, _buf, _start);
        _buf = grown;
      } else if (_start > 0) {
        _buf.setRange(0, live, _buf, _start);
      }
      _start = 0;
      _end = live;
    }
    _buf.setRange(_end, _end + data.length, data);
    _end += data.length;
  }

  /// Returns the next complete frame, or `null` if more bytes are needed.
  /// Throws [FrameFormatException] on any malformed or oversized frame.
  WireFrame? next() {
    if (_pendingHeader == null) {
      if (_end - _start < 4) return null;
      final headerLen =
          ByteData.sublistView(_buf, _start, _start + 4).getUint32(0, Endian.big);
      if (headerLen == 0 || headerLen > FrameLimits.maxHeaderBytes) {
        throw FrameFormatException('invalid header length $headerLen');
      }
      if (_end - _start < 4 + headerLen) return null;

      final Object? decoded;
      try {
        decoded = jsonDecode(utf8.decode(
          Uint8List.sublistView(_buf, _start + 4, _start + 4 + headerLen),
        ));
      } on FormatException {
        throw const FrameFormatException('header is not valid JSON');
      }
      if (decoded is! Map<String, dynamic>) {
        throw const FrameFormatException('header must be a JSON object');
      }
      final payloadLen = decoded['payloadLen'];
      if (payloadLen is! int ||
          payloadLen < 0 ||
          payloadLen > FrameLimits.maxPayloadBytes) {
        throw const FrameFormatException('invalid payload length');
      }
      _pendingHeader = decoded;
      _pendingHeaderLen = headerLen;
      _pendingPayloadLen = payloadLen;
    }

    final total = 4 + _pendingHeaderLen + _pendingPayloadLen;
    if (_end - _start < total) return null;

    final payloadStart = _start + 4 + _pendingHeaderLen;
    final payload = _pendingPayloadLen == 0
        ? Uint8List(0)
        : Uint8List.fromList(
            Uint8List.sublistView(_buf, payloadStart, payloadStart + _pendingPayloadLen),
          );
    final frame = WireFrame(_pendingHeader!, payload);

    _start += total;
    if (_start == _end) {
      _start = 0;
      _end = 0;
    }
    _pendingHeader = null;
    return frame;
  }
}

/// Reads frames from a socket-like stream so a sender can wait for replies
/// (handshake accept, final ack) while the same socket is used for writing.
class FrameInbox {
  final FrameReader _reader = FrameReader();
  final Queue<WireFrame> _ready = Queue<WireFrame>();
  Completer<void>? _waiter;
  Object? _error;
  bool _closed = false;
  late final StreamSubscription<List<int>> _sub;

  FrameInbox(Stream<List<int>> source) {
    _sub = source.listen(
      (data) {
        try {
          _reader.add(data);
          for (WireFrame? f = _reader.next(); f != null; f = _reader.next()) {
            _ready.add(f);
          }
        } catch (e) {
          _error = e;
        }
        _wake();
      },
      onError: (Object e) {
        _error = e;
        _wake();
      },
      onDone: () {
        _closed = true;
        _wake();
      },
      cancelOnError: true,
    );
  }

  void _wake() {
    final w = _waiter;
    _waiter = null;
    if (w != null && !w.isCompleted) w.complete();
  }

  /// Next frame, or throws on malformed data, closed connection or timeout.
  Future<WireFrame> next({Duration timeout = const Duration(seconds: 30)}) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      if (_ready.isNotEmpty) return _ready.removeFirst();
      final err = _error;
      if (err != null) throw err;
      if (_closed) throw const FrameFormatException('connection closed');
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        throw TimeoutException('timed out waiting for the other device');
      }
      final w = Completer<void>();
      _waiter = w;
      await w.future.timeout(remaining, onTimeout: () {});
    }
  }

  Future<void> cancel() => _sub.cancel();
}

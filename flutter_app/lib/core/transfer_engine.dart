import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:cryptography_flutter/cryptography_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/transfer_models.dart';
import '../services/platform_bridge.dart';
import 'approval.dart';
import 'bundle/bundle_io.dart';
import 'partial_transfer.dart';
import 'security/frame_codec.dart';
import 'security/pairing.dart';
import 'security/safe_names.dart';
import 'security/session_crypto.dart';

class _IsolateSenderConfig {
  final SendPort uiPort;
  final String taskId;
  final String filePath;
  final String fileName;
  final int totalBytes;
  final String targetHost;
  final int targetPort;
  final int chunkSizeBytes;
  final bool encrypted;
  final String senderName;
  final String? pairingRpk;
  final String? pairingPsk;

  const _IsolateSenderConfig({
    required this.uiPort,
    required this.taskId,
    required this.filePath,
    required this.fileName,
    required this.totalBytes,
    required this.targetHost,
    required this.targetPort,
    required this.chunkSizeBytes,
    required this.encrypted,
    required this.senderName,
    this.pairingRpk,
    this.pairingPsk,
  });
}

class ActiveSenderHandle {
  final SendPort controlPort;
  final Isolate isolate;

  const ActiveSenderHandle({
    required this.controlPort,
    required this.isolate,
  });

  void pause() => controlPort.send('pause');
  void resume() => controlPort.send('resume');
  void cancel() => controlPort.send('cancel');
}

class TransferEngine {
  static const int defaultTcpPort = 47890;
  static const int _maxFileBytes = 1 << 40; // 1 TiB sanity cap for a declared file size

  static const int _maxIncomingConnections = 8;
  static const int _maxReconnects = 5;
  static const Duration _handshakeDeadline = Duration(seconds: 15);

  ServerSocket? _serverSocket;
  final Map<String, ActiveSenderHandle> _activeSenders = {};
  final Map<String, void Function()> _receiverCancels = {};
  PairingOffer? _offer;
  int _incoming = 0;
  final Map<String, PartialTransfer> _partials = {};

  /// Accept transfers that the sender chose not to encrypt (the sender's own toggle).
  /// Still true on purpose: the approval screen then shows a clear "not encrypted"
  /// warning and the receiving user must tap Accept. Set false to refuse outright.
  bool acceptPlaintext = true;

  /// When true, only senders that scanned this device's QR code are accepted.
  /// Default stays false: nearby-list senders are allowed, and the receiving user
  /// compares the match code on the approval screen before tapping Accept.
  bool requireAuthenticatedPeers = false;

  /// The receiving user must accept each new transfer (see docs/PROTOCOL_LAN_V2.md,
  /// "Approval"). Resumed transfers skip it: the user already said yes.
  final ApprovalBroker approvals = ApprovalBroker();

  /// How long a sender waits for the receiving user to decide (longer than the
  /// receiver's own timeout, so the receiver's refusal always arrives first).
  static const Duration _approvalWait = Duration(seconds: 90);

  final _handshakeController = StreamController<HandshakeInfo>.broadcast();

  /// Emits the 6-digit match code (identical on both devices) after every handshake.
  Stream<HandshakeInfo> get handshakes => _handshakeController.stream;

  /// Creates a fresh QR pairing offer (new X25519 key + random secret, valid 10 minutes).
  Future<PairingPayload> createPairingOffer() async {
    enableHardwareCrypto(); // must run before the first crypto object is created
    _offer = await PairingOffer.create();
    return _offer!.payload;
  }

  final _taskUpdatesController = StreamController<TransferTask>.broadcast();
  Stream<TransferTask> get taskUpdates => _taskUpdatesController.stream;

  int? get listeningPort => _serverSocket?.port;

  static void enableHardwareCrypto() {
    try {
      FlutterCryptography.enable();
    } catch (_) {
      // Fallback safely to pure Dart cryptography on unsupported platforms
    }
  }

  Future<int> startTcpReceiver({
    required String localDeviceName,
    int port = defaultTcpPort,
  }) async {
    await stopTcpReceiver();
    enableHardwareCrypto();

    try {
      _serverSocket = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        port,
        shared: true,
      );
    } catch (_) {
      _serverSocket = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        0,
        shared: true,
      );
    }

    _serverSocket!.listen((Socket client) {
      client.setOption(SocketOption.tcpNoDelay, true);
      _handleIncomingConnection(client);
    });

    return _serverSocket!.port;
  }

  Future<void> stopTcpReceiver() async {
    await _serverSocket?.close();
    _serverSocket = null;
  }

  Future<void> sendFile({
    required String taskId,
    required String filePath,
    required String fileName,
    required int totalBytes,
    required PeerDevice targetPeer,
    required String senderName,
    required int chunkSizeKb,
    required bool encrypted,
    PairingPayload? pairing,
  }) async {
    final receivePort = ReceivePort();
    final controlReady = Completer<SendPort>();

    final config = _IsolateSenderConfig(
      uiPort: receivePort.sendPort,
      taskId: taskId,
      filePath: filePath,
      fileName: fileName,
      totalBytes: totalBytes,
      targetHost: targetPeer.host,
      targetPort: targetPeer.port,
      chunkSizeBytes: chunkSizeKb * 1024,
      encrypted: encrypted,
      senderName: senderName,
      pairingRpk: pairing == null ? null : b64u(pairing.receiverPublicKey),
      pairingPsk: pairing == null ? null : b64u(pairing.psk),
    );

    final isolate = await Isolate.spawn(
      _senderIsolateEntry,
      config,
      debugName: 'vega-sender-$taskId',
    );

    receivePort.listen((dynamic message) {
      if (message is SendPort) {
        if (!controlReady.isCompleted) controlReady.complete(message);
        return;
      }
      if (message is Map<String, dynamic>) {
        final sas = message['sas'] as String?;
        if (sas != null && !_handshakeController.isClosed) {
          _handshakeController.add(
            HandshakeInfo(
              taskId: taskId,
              sas: sas,
              authenticated: (message['authenticated'] as bool?) ?? false,
              outgoing: true,
            ),
          );
        }
        final statusName = message['status'] as String;
        final status = TransferStatus.values.firstWhere(
          (e) => e.name == statusName,
          orElse: () => TransferStatus.transferring,
        );
        final task = TransferTask(
          id: taskId,
          fileName: fileName,
          totalBytes: totalBytes,
          transferredBytes: (message['transferredBytes'] as int?) ?? 0,
          speedBytesPerSec: (message['speed'] as double?) ?? 0.0,
          direction: TransferDirection.send,
          status: status,
          peerName: targetPeer.name,
          sha256Hex: message['sha256Hex'] as String?,
          integrityVerified: (message['integrityVerified'] as bool?) ?? false,
          encrypted: encrypted,
          errorMessage: message['error'] as String?,
          updatedAt: DateTime.now(),
        );
        if (!_taskUpdatesController.isClosed) {
          _taskUpdatesController.add(task);
        }

        if (status == TransferStatus.completed ||
            status == TransferStatus.failed ||
            status == TransferStatus.cancelled) {
          _activeSenders.remove(taskId);
          receivePort.close();
          isolate.kill(priority: Isolate.immediate);
        }
      }
    });

    final controlPort = await controlReady.future;
    _activeSenders[taskId] = ActiveSenderHandle(
      controlPort: controlPort,
      isolate: isolate,
    );
  }

  void pauseTransfer(String taskId) => _activeSenders[taskId]?.pause();
  void resumeTransfer(String taskId) => _activeSenders[taskId]?.resume();
  void cancelTransfer(String taskId) {
    _activeSenders[taskId]?.cancel();
    _receiverCancels[taskId]?.call();
  }

  /// Runs completely off the Flutter UI thread for maximum Wi-Fi Direct / LAN throughput.
  static Future<void> _senderIsolateEntry(_IsolateSenderConfig config) async {
    enableHardwareCrypto();
    final controlPort = ReceivePort();
    config.uiPort.send(controlPort.sendPort);

    bool isPaused = false;
    bool isCancelled = false;
    Completer<void>? resumeGate;

    controlPort.listen((dynamic cmd) {
      if (cmd == 'pause') {
        isPaused = true;
      } else if (cmd == 'resume') {
        isPaused = false;
        resumeGate?.complete();
        resumeGate = null;
      } else if (cmd == 'cancel') {
        isCancelled = true;
        isPaused = false;
        resumeGate?.complete();
        resumeGate = null;
      }
    });

    void emit(
      TransferStatus status, {
      int transferredBytes = 0,
      double speed = 0,
      String? sha256Hex,
      bool integrityVerified = false,
      String? error,
      String? sas,
      bool authenticated = false,
    }) {
      config.uiPort.send(<String, dynamic>{
        'status': status.name,
        'transferredBytes': transferredBytes,
        'speed': speed,
        'sha256Hex': sha256Hex,
        'integrityVerified': integrityVerified,
        'error': error,
        'sas': sas,
        'authenticated': authenticated,
      });
    }

    // State that survives a dropped connection (see "Resume" in docs/PROTOCOL_LAN_V2.md).
    int offset = 0;
    int chunkIndex = 0;
    SecretKey? resumeKey;
    int reconnects = 0;
    final stopwatch = Stopwatch()..start();
    int lastEmitMs = 0;

    Socket? socket;
    FrameInbox? inbox;
    RandomAccessFile? raf;

    Future<void> closeConnection() async {
      try {
        await inbox?.cancel();
      } catch (_) {}
      try {
        socket?.destroy();
      } catch (_) {}
      inbox = null;
      socket = null;
    }

    // Only network-level drops are retried; refusals, bad data and failed
    // verification are final.
    bool isDropped(Object e) =>
        e is SocketException ||
        e is TimeoutException ||
        (e is FrameFormatException && e.message == 'connection closed');

    try {
      final file = await File(config.filePath).open(mode: FileMode.read);
      raf = file;

      Future<void> attempt() async {
        emit(TransferStatus.connecting, transferredBytes: offset);
        final sock = await Socket.connect(
          config.targetHost,
          config.targetPort,
          timeout: const Duration(seconds: 12),
        );
        socket = sock;
        sock.setOption(SocketOption.tcpNoDelay, true);
        final inb = FrameInbox(sock);
        inbox = inb;

        // ---- Handshake (docs/PROTOCOL_LAN_V2.md) ---------------------------------
        final resuming = resumeKey != null;
        final qr = config.pairingRpk != null && config.pairingPsk != null;
        final Uint8List? rpk = qr ? fromB64u(config.pairingRpk!) : null;
        final Uint8List? psk = qr ? fromB64u(config.pairingPsk!) : null;
        final ephemeral = await LanV2Crypto.newKeyPair();
        final ePub = await LanV2Crypto.publicBytes(ephemeral);

        await _writeFrame(sock, {
          'type': 'init',
          'v': 2,
          'mode': qr ? 'qr' : 'open',
          'id': config.taskId,
          'fileName': config.fileName,
          'totalBytes': config.totalBytes,
          'chunkSizeBytes': config.chunkSizeBytes,
          'encrypted': config.encrypted,
          'senderName': config.senderName,
          'epk': b64u(ePub),
          if (qr) 'rpk': config.pairingRpk,
          if (resuming) 'resume': true,
        });
        await sock.flush();

        final accept = await inb.next(timeout: const Duration(seconds: 60));
        if (accept.header['type'] == 'reject') {
          throw Exception(
            'Receiver refused: ${accept.header['reason'] ?? 'no reason given'}',
          );
        }
        if (accept.header['type'] != 'accept') {
          throw const FrameFormatException('unexpected reply to init');
        }
        final fPub = fromB64u((accept.header['fpk'] as String?) ?? '');
        if (fPub.length != 32) {
          throw const FrameFormatException('invalid receiver key');
        }
        final transcript = await LanV2Crypto.transcriptHash(
          params: HandshakeParams(
            qr: qr,
            encrypted: config.encrypted,
            totalBytes: config.totalBytes,
            chunkSize: config.chunkSizeBytes,
            fileName: config.fileName,
            taskId: config.taskId,
          ),
          ephemeralSender: ePub,
          ephemeralReceiver: fPub,
          staticReceiver: rpk,
        );
        final keys = await LanV2Crypto.derive(
          qr: qr,
          dhEphemeral: await LanV2Crypto.dh(ephemeral, fPub),
          dhStatic: qr ? await LanV2Crypto.dh(ephemeral, rpk!) : null,
          psk: psk,
          transcript: transcript,
        );
        final expectedAccept =
            await LanV2Crypto.acceptConfirm(keys.confirmKey, transcript);
        final gotAccept = base64Decode((accept.header['confirm'] as String?) ?? '');
        if (!LanV2Crypto.bytesEqual(expectedAccept, gotAccept)) {
          throw Exception(
            'Receiver could not be verified. Scan its QR code again and retry.',
          );
        }
        // A resumed transfer was approved earlier, so no code is shown for it.
        emit(
          TransferStatus.connecting,
          sas: resuming ? null : keys.sas,
          authenticated: qr,
        );
        // ----------------------------------------------------------------------------

        if (!resuming) {
          // Approval: the receiving user compares the match code and taps Accept.
          // Polling in 1 s steps keeps Cancel responsive; frames are never lost.
          final waitUntil = DateTime.now().add(_approvalWait);
          while (true) {
            if (isCancelled) {
              await _writeFrame(sock, {'type': 'cancel', 'id': config.taskId});
              await sock.flush();
              emit(TransferStatus.cancelled, transferredBytes: offset);
              return;
            }
            try {
              final reply = await inb.next(timeout: const Duration(seconds: 1));
              final replyType = reply.header['type'];
              if (replyType == 'reject') {
                throw Exception(
                  'Receiver refused: ${reply.header['reason'] ?? 'no reason given'}',
                );
              }
              if (replyType == 'go') break;
              throw const FrameFormatException('unexpected reply while waiting for approval');
            } on TimeoutException {
              if (DateTime.now().isAfter(waitUntil)) {
                throw Exception('The receiver did not respond in time');
              }
            }
          }
        }

        if (resuming) {
          // Prove we are the sender of the interrupted session, then continue from the
          // position the receiver confirms (never beyond what we already sent).
          await _writeFrame(sock, {
            'type': 'resume',
            'proof': base64Encode(
              await LanV2Crypto.resumeProof(resumeKey!, transcript),
            ),
          });
          await sock.flush();
          final r = await inb.next(timeout: const Duration(seconds: 60));
          if (r.header['type'] == 'reject') {
            throw Exception(
              'Receiver refused: ${r.header['reason'] ?? 'no reason given'}',
            );
          }
          if (r.header['type'] != 'resumed') {
            throw const FrameFormatException('unexpected reply to resume');
          }
          final rOff = r.header['offset'];
          final rIdx = r.header['index'];
          if (rOff is! int ||
              rIdx is! int ||
              rOff < 0 ||
              rOff > offset ||
              rIdx < 0 ||
              rIdx > chunkIndex) {
            throw Exception('Receiver sent an invalid resume position');
          }
          final expectedResumed = await LanV2Crypto.resumedConfirm(
            keys.confirmKey,
            offset: rOff,
            index: rIdx,
          );
          final gotResumed = base64Decode((r.header['confirm'] as String?) ?? '');
          if (!LanV2Crypto.bytesEqual(expectedResumed, gotResumed)) {
            throw Exception('Resume confirmation could not be verified');
          }
          offset = rOff;
          chunkIndex = rIdx;
        }
        // Rotate: both sides keep the newest session's key for any further drop.
        resumeKey = keys.resumeKey;

        final aes = LanV2Crypto.aes;
        final sessionKey = keys.sessionKey;

        // The whole-file hash is recomputed over the bytes the receiver already holds.
        final digestSink = AccumulatorSink<Digest>();
        final shaInput = sha256.startChunkedConversion(digestSink);
        await file.setPosition(0);
        int hashed = 0;
        while (hashed < offset) {
          final want = offset - hashed < (1 << 20) ? offset - hashed : (1 << 20);
          final block = await file.read(want);
          if (block.isEmpty) throw Exception('File changed while sending');
          shaInput.add(block);
          hashed += block.length;
        }

        while (offset < config.totalBytes) {
          if (isCancelled) {
            await _writeFrame(sock, {'type': 'cancel', 'id': config.taskId});
            await sock.flush();
            emit(TransferStatus.cancelled, transferredBytes: offset);
            return;
          }
          if (isPaused) {
            emit(TransferStatus.paused, transferredBytes: offset, speed: 0);
            resumeGate = Completer<void>();
            await resumeGate!.future;
            if (isCancelled) {
              emit(TransferStatus.cancelled, transferredBytes: offset);
              return;
            }
          }

          final remaining = config.totalBytes - offset;
          final toRead =
              remaining < config.chunkSizeBytes ? remaining : config.chunkSizeBytes;
          final plainBytes = await file.read(toRead);
          if (plainBytes.isEmpty) throw Exception('File changed while sending');

          shaInput.add(plainBytes);

          if (config.encrypted) {
            final box = await aes.encrypt(
              plainBytes,
              secretKey: sessionKey,
              aad: LanV2Crypto.chunkAad(chunkIndex, offset, plainBytes.length),
            );
            await _writeFrame(
              sock,
              {
                'type': 'chunk',
                'index': chunkIndex,
                'offset': offset,
                'plainSize': plainBytes.length,
                'nonce': base64Encode(box.nonce),
                'mac': base64Encode(box.mac.bytes),
              },
              payload: Uint8List.fromList(box.cipherText),
            );
          } else {
            await _writeFrame(
              sock,
              {
                'type': 'chunk',
                'index': chunkIndex,
                'offset': offset,
                'plainSize': plainBytes.length,
              },
              payload: plainBytes,
            );
          }

          offset += plainBytes.length;
          chunkIndex++;

          // Bounded memory: let the socket drain every 4 chunks (default ~4 MB in
          // flight) instead of queueing the whole file. Reading/encrypting continues
          // in between.
          if ((chunkIndex & 3) == 0) {
            await sock.flush();
          }

          final elapsedMs = stopwatch.elapsedMilliseconds;
          if (elapsedMs - lastEmitMs >= 100 || offset >= config.totalBytes) {
            lastEmitMs = elapsedMs;
            final secs = elapsedMs > 0 ? elapsedMs / 1000.0 : 0.001;
            emit(
              TransferStatus.transferring,
              transferredBytes: offset,
              speed: offset / secs,
            );
          }
        }

        shaInput.close();
        final digestHex = digestSink.events.single.toString();

        emit(
          TransferStatus.verifying,
          transferredBytes: offset,
          sha256Hex: digestHex,
        );

        await _writeFrame(sock, {
          'type': 'complete',
          'id': config.taskId,
          'sha256Hex': digestHex,
        });
        await sock.flush();

        // "Verified" is only reported after the receiver proves (with a MAC under the
        // handshake key) that it received and hashed exactly what we sent.
        final done = await inb.next(timeout: const Duration(seconds: 120));
        if (done.header['type'] != 'done') {
          throw const FrameFormatException('unexpected final reply');
        }
        final ok = done.header['ok'] == true;
        final recvSha = (done.header['sha256Hex'] as String?) ?? '';
        final recvBytesRaw = done.header['bytes'];
        final recvBytes = recvBytesRaw is int ? recvBytesRaw : -1;
        final expectedDone = await LanV2Crypto.doneConfirm(
          keys.confirmKey,
          ok: ok,
          sha256Hex: recvSha,
          bytes: recvBytes,
        );
        final gotDone = base64Decode((done.header['confirm'] as String?) ?? '');
        if (!LanV2Crypto.bytesEqual(expectedDone, gotDone)) {
          throw Exception('Final confirmation from the receiver could not be verified');
        }
        if (!(ok && recvSha == digestHex && recvBytes == config.totalBytes)) {
          throw Exception('Receiver reported that the file did not verify');
        }

        emit(
          TransferStatus.completed,
          transferredBytes: config.totalBytes,
          speed: offset / (stopwatch.elapsedMilliseconds.clamp(1, 1 << 30) / 1000.0),
          sha256Hex: digestHex,
          integrityVerified: true,
        );
      }

      while (true) {
        try {
          await attempt();
          break; // completed or cancelled (both already reported)
        } catch (e) {
          final canRetry = resumeKey != null &&
              isDropped(e) &&
              !isCancelled &&
              reconnects < _maxReconnects;
          await closeConnection();
          if (!canRetry) rethrow;
          reconnects++;
          emit(TransferStatus.connecting, transferredBytes: offset);
          await Future<void>.delayed(Duration(seconds: 1 << (reconnects - 1)));
        }
      }
    } catch (e) {
      emit(TransferStatus.failed, error: e.toString());
    } finally {
      await closeConnection();
      await raf?.close();
      controlPort.close();
    }
  }

  Future<void> _handleIncomingConnection(Socket socket) async {
    if (_incoming >= _maxIncomingConnections) {
      socket.destroy();
      return;
    }
    _incoming++;

    String taskId = 'rx-${DateTime.now().millisecondsSinceEpoch}';
    String fileName = 'incoming_file';
    String senderName = 'Nearby Device';
    int totalBytes = 0;
    bool encrypted = true;
    bool initialised = false;
    SecretKey? sessionKey;
    SecretKey? confirmKey;
    IOSink? tempSink;
    File? tempFile;
    final digestSink = AccumulatorSink<Digest>();
    late final ByteConversionSink shaInput;
    bool shaStarted = false;
    bool finished = false;
    int receivedBytes = 0;
    int expectedIndex = 0;
    final stopwatch = Stopwatch()..start();
    int lastEmitMs = 0;

    final aes = LanV2Crypto.aes;
    final reader = FrameReader();

    bool resumeRequested = false;
    bool resumeHandled = false;
    String rawFileNameStored = '';
    int chunkSizeDeclared = 0;
    SecretKey? newResumeKey;
    Uint8List? handshakeTranscript;

    // A peer that connects and never completes the handshake must not hold a slot.
    final handshakeTimer = Timer(_handshakeDeadline, () {
      if (!initialised) socket.destroy();
    });

    Future<void> discardTemp() async {
      try {
        await tempSink?.close();
      } catch (_) {}
      tempSink = null;
      try {
        if (tempFile != null && await tempFile!.exists()) {
          await tempFile!.delete();
        }
      } catch (_) {}
    }

    Future<void> startFresh() async {
      final tempDir = await getTemporaryDirectory();
      // Random prefix: peer-controlled values never decide where the temp file lives.
      tempFile = File(p.join(tempDir.path, '${randomHex(8)}_$fileName'));
      tempSink = tempFile!.openWrite();
      shaInput = sha256.startChunkedConversion(digestSink);
      shaStarted = true;
      receivedBytes = 0;
      expectedIndex = 0;
      _emitTask(
        TransferTask(
          id: taskId,
          fileName: fileName,
          totalBytes: totalBytes,
          direction: TransferDirection.receive,
          status: TransferStatus.transferring,
          peerName: senderName,
          encrypted: encrypted,
          updatedAt: DateTime.now(),
        ),
      );
    }

    // Connection dropped: keep the verified part so the same sender can resume.
    Future<void> parkPartial() async {
      final f = tempFile;
      final key = newResumeKey;
      if (f == null || tempSink == null || key == null) {
        await discardTemp();
        return;
      }
      try {
        await tempSink!.flush();
        await tempSink!.close();
      } catch (_) {
        tempSink = null;
        await discardTemp();
        return;
      }
      tempSink = null;
      finished = true;
      _storePartial(
        PartialTransfer(
          taskId: taskId,
          rawFileName: rawFileNameStored,
          fileName: fileName,
          senderName: senderName,
          totalBytes: totalBytes,
          chunkSize: chunkSizeDeclared,
          encrypted: encrypted,
          file: f,
          bytes: receivedBytes,
          nextIndex: expectedIndex,
          resumeKey: key,
        ),
      );
      _emitTask(
        TransferTask(
          id: taskId,
          fileName: fileName,
          totalBytes: totalBytes,
          transferredBytes: receivedBytes,
          direction: TransferDirection.receive,
          status: TransferStatus.paused,
          peerName: senderName,
          encrypted: encrypted,
          errorMessage: 'Connection lost. Waiting for the sender to resume',
          updatedAt: DateTime.now(),
        ),
      );
    }

    Future<Never> reject(String reason) async {
      try {
        await _writeFrame(socket, {'type': 'reject', 'reason': reason});
        await socket.flush();
      } catch (_) {}
      throw FrameFormatException(reason);
    }

    try {
      await for (final Uint8List packet in socket) {
        reader.add(packet);
        // FrameReader is linear-time and throws FrameFormatException on malformed or
        // oversized frames, which lands in the catch below and closes the socket.
        for (WireFrame? frame = reader.next(); frame != null; frame = reader.next()) {
          final header = frame.header;
          final payload = frame.payload;
          final type = header['type'];

          if (type == 'init') {
            if (initialised) {
              throw const FrameFormatException('duplicate init frame');
            }
            if (header['v'] != 2) await reject('Unsupported protocol version');
            final rawId = header['id'];
            if (rawId is! String || !isSafeTaskId(rawId)) {
              await reject('Invalid transfer id');
            }
            taskId = rawId as String;
            final rawName = header['fileName'];
            if (rawName is! String) await reject('Invalid file name');
            final rawFileName = rawName as String;
            fileName = sanitizeFileName(rawFileName, fallback: fileName);
            final rawSender = header['senderName'];
            if (rawSender is String && rawSender.isNotEmpty) {
              senderName = rawSender.runes.length > 64
                  ? String.fromCharCodes(rawSender.runes.take(64))
                  : rawSender;
            }
            final rawTotal = header['totalBytes'];
            if (rawTotal is! int || rawTotal < 0 || rawTotal > _maxFileBytes) {
              await reject('Invalid file size');
            }
            totalBytes = rawTotal as int;
            final chunkSize = header['chunkSizeBytes'];
            if (chunkSize is! int ||
                chunkSize <= 0 ||
                chunkSize > FrameLimits.maxPayloadBytes) {
              await reject('Invalid chunk size');
            }
            encrypted = header['encrypted'] == true;
            if (!encrypted && !acceptPlaintext) {
              await reject('This device only accepts encrypted transfers');
            }
            final mode = header['mode'];
            if (mode != 'qr' && mode != 'open') await reject('Invalid mode');
            final qr = mode == 'qr';
            final epk = fromB64u((header['epk'] as String?) ?? '');
            if (epk.length != 32) await reject('Invalid key');

            PairingOffer? offer;
            if (qr) {
              offer = _offer;
              final sentRpk = fromB64u((header['rpk'] as String?) ?? '');
              if (offer == null ||
                  offer.isExpired ||
                  !LanV2Crypto.bytesEqual(sentRpk, offer.payload.receiverPublicKey)) {
                await reject('Pairing code expired or does not match. Scan the QR code again.');
              }
            } else if (requireAuthenticatedPeers) {
              await reject('This device only accepts transfers started from its QR code');
            }

            final fKeyPair = await LanV2Crypto.newKeyPair();
            final fPub = await LanV2Crypto.publicBytes(fKeyPair);
            final transcript = await LanV2Crypto.transcriptHash(
              params: HandshakeParams(
                qr: qr,
                encrypted: encrypted,
                totalBytes: totalBytes,
                chunkSize: chunkSize as int,
                fileName: rawFileName,
                taskId: taskId,
              ),
              ephemeralSender: epk,
              ephemeralReceiver: fPub,
              staticReceiver: qr ? offer!.payload.receiverPublicKey : null,
            );
            final keys = await LanV2Crypto.derive(
              qr: qr,
              dhEphemeral: await LanV2Crypto.dh(fKeyPair, epk),
              dhStatic: qr ? await LanV2Crypto.dh(offer!.keyPair, epk) : null,
              psk: qr ? offer!.payload.psk : null,
              transcript: transcript,
            );
            sessionKey = keys.sessionKey;
            confirmKey = keys.confirmKey;

            await _writeFrame(socket, {
              'type': 'accept',
              'fpk': b64u(fPub),
              'confirm': base64Encode(
                await LanV2Crypto.acceptConfirm(keys.confirmKey, transcript),
              ),
            });
            await socket.flush();
            if (!_handshakeController.isClosed) {
              _handshakeController.add(
                HandshakeInfo(taskId: taskId, sas: keys.sas, authenticated: qr),
              );
            }

            rawFileNameStored = rawFileName;
            chunkSizeDeclared = chunkSize as int;
            newResumeKey = keys.resumeKey;
            handshakeTranscript = transcript;
            resumeRequested = header['resume'] == true;

            initialised = true;
            handshakeTimer.cancel();
            // Lets the receiving user stop this transfer; the partial file is discarded.
            final rxTaskId = taskId;
            _receiverCancels[rxTaskId] = () {
              if (finished) return;
              finished = true;
              unawaited(discardTemp());
              _emitTask(
                TransferTask(
                  id: rxTaskId,
                  fileName: fileName,
                  totalBytes: totalBytes,
                  transferredBytes: receivedBytes,
                  direction: TransferDirection.receive,
                  status: TransferStatus.cancelled,
                  peerName: senderName,
                  encrypted: encrypted,
                  errorMessage: 'Aapne transfer rok diya',
                  updatedAt: DateTime.now(),
                ),
              );
              socket.destroy();
            };
            // A reconnecting sender continues with a `resume` frame instead.
            if (!resumeRequested) {
              // Wait for the user's Accept / Reject, then tell the sender to start.
              final approved = await approvals.request(
                taskId: taskId,
                senderName: senderName,
                fileName: fileName,
                totalBytes: totalBytes,
                encrypted: encrypted,
                authenticated: qr,
                sas: keys.sas,
              );
              if (!approved) {
                finished = true;
                try {
                  await _writeFrame(socket, {
                    'type': 'reject',
                    'reason': 'Declined by the receiver',
                  });
                  await socket.flush();
                } catch (_) {}
                _emitTask(
                  TransferTask(
                    id: taskId,
                    fileName: fileName,
                    totalBytes: totalBytes,
                    direction: TransferDirection.receive,
                    status: TransferStatus.cancelled,
                    peerName: senderName,
                    encrypted: encrypted,
                    errorMessage: 'Declined',
                    updatedAt: DateTime.now(),
                  ),
                );
                return;
              }
              await _writeFrame(socket, {'type': 'go'});
              await socket.flush();
              await startFresh();
            }
          } else if (!initialised) {
            throw const FrameFormatException('frame received before init');
          } else if (type == 'resume' && resumeRequested && !resumeHandled) {
            resumeHandled = true;
            final cand = _partials[taskId];
            bool continued = false;
            if (cand != null &&
                cand.matches(
                  rawFileName: rawFileNameStored,
                  totalBytes: totalBytes,
                  chunkSize: chunkSizeDeclared,
                  encrypted: encrypted,
                )) {
              final expectedProof = await LanV2Crypto.resumeProof(
                cand.resumeKey,
                handshakeTranscript!,
              );
              final gotProof = base64Decode((header['proof'] as String?) ?? '');
              if (!LanV2Crypto.bytesEqual(expectedProof, gotProof)) {
                await reject('Resume proof invalid');
              }
              _partials.remove(taskId);
              cand.timer?.cancel();
              tempFile = cand.file;
              // Re-hash what is already on disk so the final SHA-256 covers the whole file.
              shaInput = sha256.startChunkedConversion(digestSink);
              shaStarted = true;
              await for (final block in tempFile!.openRead()) {
                shaInput.add(block);
              }
              tempSink = tempFile!.openWrite(mode: FileMode.append);
              receivedBytes = cand.bytes;
              expectedIndex = cand.nextIndex;
              continued = true;
              _emitTask(
                TransferTask(
                  id: taskId,
                  fileName: fileName,
                  totalBytes: totalBytes,
                  transferredBytes: receivedBytes,
                  direction: TransferDirection.receive,
                  status: TransferStatus.transferring,
                  peerName: senderName,
                  encrypted: encrypted,
                  updatedAt: DateTime.now(),
                ),
              );
            }
            if (!continued) await startFresh();
            await _writeFrame(socket, {
              'type': 'resumed',
              'offset': receivedBytes,
              'index': expectedIndex,
              'confirm': base64Encode(
                await LanV2Crypto.resumedConfirm(
                  confirmKey!,
                  offset: receivedBytes,
                  index: expectedIndex,
                ),
              ),
            });
            await socket.flush();
          } else if (type == 'chunk') {
            if (tempSink == null) {
              throw const FrameFormatException('chunk before the transfer is ready');
            }
            final index = header['index'];
            final off = header['offset'];
            final plainSize = header['plainSize'];
            if (index != expectedIndex ||
                off != receivedBytes ||
                plainSize is! int) {
              throw const FrameFormatException('chunk out of order');
            }
            Uint8List plainBytes;
            if (encrypted && sessionKey != null) {
              final nonce = base64Decode(header['nonce'] as String);
              final mac = Mac(base64Decode(header['mac'] as String));
              final clear = await aes.decrypt(
                SecretBox(payload, nonce: nonce, mac: mac),
                secretKey: sessionKey,
                aad: LanV2Crypto.chunkAad(index as int, off as int, plainSize),
              );
              plainBytes = Uint8List.fromList(clear);
            } else {
              plainBytes = payload;
            }
            if (plainBytes.length != plainSize) {
              throw const FrameFormatException('chunk size mismatch');
            }
            expectedIndex++;

            if (receivedBytes + plainBytes.length > totalBytes) {
              throw const FrameFormatException('sender exceeded declared file size');
            }

            tempSink!.add(plainBytes);
            shaInput.add(plainBytes);
            receivedBytes += plainBytes.length;

            final elapsedMs = stopwatch.elapsedMilliseconds;
            if (elapsedMs - lastEmitMs >= 100 || receivedBytes >= totalBytes) {
              lastEmitMs = elapsedMs;
              final secs = elapsedMs > 0 ? elapsedMs / 1000.0 : 0.001;
              _emitTask(
                TransferTask(
                  id: taskId,
                  fileName: fileName,
                  totalBytes: totalBytes,
                  transferredBytes: receivedBytes,
                  speedBytesPerSec: receivedBytes / secs,
                  direction: TransferDirection.receive,
                  status: TransferStatus.transferring,
                  peerName: senderName,
                  encrypted: encrypted,
                  updatedAt: DateTime.now(),
                ),
              );
            }
          } else if (type == 'complete' && tempSink != null && tempFile != null) {
            await tempSink!.flush();
            await tempSink!.close();
            tempSink = null;

            if (shaStarted) shaInput.close();
            final computedHex = digestSink.events.single.toString();
            final expectedHex = (header['sha256Hex'] as String?) ?? '';
            final verified = expectedHex.isNotEmpty &&
                computedHex == expectedHex &&
                receivedBytes == totalBytes;

            // Tell the sender the outcome first (authenticated with the handshake key),
            // so it never waits on the file copy below.
            await _writeFrame(socket, {
              'type': 'done',
              'ok': verified,
              'sha256Hex': computedHex,
              'bytes': receivedBytes,
              'confirm': base64Encode(
                await LanV2Crypto.doneConfirm(
                  confirmKey!,
                  ok: verified,
                  sha256Hex: computedHex,
                  bytes: receivedBytes,
                ),
              ),
            });
            await socket.flush();

            String? savedLocation;
            String? bundleError;
            if (verified) {
              // Only a fully verified file ever reaches the user's Downloads folder.
              if (BundleIo.isBundleName(fileName)) {
                // Several files sent together: open them only now that the whole
                // bundle is verified, and save each one to Downloads.
                try {
                  savedLocation = await BundleIo.unpackAndSave(tempFile!);
                } catch (e) {
                  savedLocation = null;
                  bundleError = e.toString();
                }
                await discardTemp();
              } else {
                savedLocation = await PlatformBridge.saveToDownloads(
                  sourcePath: tempFile!.path,
                  fileName: fileName,
                );
              }
              if (tempFile != null && savedLocation != tempFile!.path && await tempFile!.exists()) {
                try {
                  await tempFile!.delete();
                } catch (_) {}
              }
            } else {
              await discardTemp();
            }
            finished = true;

            _emitTask(
              TransferTask(
                id: taskId,
                fileName: fileName,
                totalBytes: totalBytes,
                transferredBytes: receivedBytes,
                speedBytesPerSec: receivedBytes /
                    (stopwatch.elapsedMilliseconds.clamp(1, 1 << 30) / 1000.0),
                direction: TransferDirection.receive,
                status: (verified && bundleError == null)
                    ? TransferStatus.completed
                    : TransferStatus.failed,
                peerName: senderName,
                sha256Hex: computedHex,
                integrityVerified: verified,
                encrypted: encrypted,
                savedLocation: savedLocation,
                errorMessage: !verified
                    ? 'Verification failed: file was discarded and not saved'
                    : (bundleError != null
                        ? 'Files kholne me dikkat aayi: $bundleError'
                        : null),
                updatedAt: DateTime.now(),
              ),
            );
          } else if (type == 'cancel') {
            await discardTemp();
            finished = true;
            _emitTask(
              TransferTask(
                id: taskId,
                fileName: fileName,
                totalBytes: totalBytes,
                transferredBytes: receivedBytes,
                direction: TransferDirection.receive,
                status: TransferStatus.cancelled,
                peerName: senderName,
                encrypted: encrypted,
                updatedAt: DateTime.now(),
              ),
            );
          }
        }
      }
      if (initialised && !finished) {
        // Connection closed mid-transfer: keep the verified part for a resume.
        await parkPartial();
      }
    } catch (e) {
      if (initialised && !finished && (e is SocketException || e is TimeoutException)) {
        await parkPartial();
      } else {
        await discardTemp();
      }
      if (initialised && !finished) {
        _emitTask(
          TransferTask(
            id: taskId,
            fileName: fileName,
            totalBytes: totalBytes,
            transferredBytes: receivedBytes,
            direction: TransferDirection.receive,
            status: TransferStatus.failed,
            peerName: senderName,
            encrypted: encrypted,
            errorMessage: e.toString(),
            updatedAt: DateTime.now(),
          ),
        );
      }
    } finally {
      handshakeTimer.cancel();
      _receiverCancels.remove(taskId);
      _incoming--;
      await socket.close();
    }
  }

  /// Keeps an interrupted receive so the same sender can continue it (10 minutes).
  void _storePartial(PartialTransfer part) {
    final old = _partials.remove(part.taskId);
    if (old != null) unawaited(old.deleteFile());
    while (_partials.length >= PartialTransfer.maxParked) {
      final oldestKey = _partials.keys.first;
      final evicted = _partials.remove(oldestKey);
      if (evicted != null) unawaited(evicted.deleteFile());
    }
    part.timer = Timer(PartialTransfer.lifetime, () {
      if (identical(_partials[part.taskId], part)) {
        _partials.remove(part.taskId);
        unawaited(part.deleteFile());
        _emitTask(
          TransferTask(
            id: part.taskId,
            fileName: part.fileName,
            totalBytes: part.totalBytes,
            transferredBytes: part.bytes,
            direction: TransferDirection.receive,
            status: TransferStatus.failed,
            peerName: part.senderName,
            encrypted: part.encrypted,
            errorMessage: 'The sender did not resume in time; partial file removed',
            updatedAt: DateTime.now(),
          ),
        );
      }
    });
    _partials[part.taskId] = part;
  }

  void _emitTask(TransferTask task) {
    if (!_taskUpdatesController.isClosed) {
      _taskUpdatesController.add(task);
    }
  }

  static Future<void> _writeFrame(
    Socket socket,
    Map<String, dynamic> header, {
    Uint8List? payload,
  }) async {
    final fullHeader = Map<String, dynamic>.from(header);
    fullHeader['payloadLen'] = payload?.length ?? 0;
    final headerBytes = utf8.encode(jsonEncode(fullHeader));

    final prefix = ByteData(4)..setUint32(0, headerBytes.length, Endian.big);
    socket.add(prefix.buffer.asUint8List());
    socket.add(headerBytes);
    if (payload != null && payload.isNotEmpty) {
      socket.add(payload);
    }
  }

  Future<void> dispose() async {
    for (final handle in _activeSenders.values) {
      handle.cancel();
    }
    _activeSenders.clear();
    _receiverCancels.clear();
    await stopTcpReceiver();
    await _taskUpdatesController.close();
    for (final part in _partials.values) {
      await part.deleteFile();
    }
    _partials.clear();
    await _handshakeController.close();
    await approvals.dispose();
  }
}

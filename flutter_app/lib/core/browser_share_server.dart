import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import '../models/transfer_models.dart';
import '../services/platform_bridge.dart';
import 'security/access_key.dart';
import 'security/safe_names.dart';

class SharedBrowserFile {
  final String id;
  final String name;
  final String path;
  final int size;

  const SharedBrowserFile({
    required this.id,
    required this.name,
    required this.path,
    required this.size,
  });
}

/// Embedded local HTTP server enabling Android <-> Windows/Mac/iOS Browser transfers
/// over Wi-Fi or Local Hotspot with zero extra software installed on the peer browser.
class BrowserShareServer {
  HttpServer? _server;
  static const int _maxUploadBytes = 1 << 36; // 64 GiB hard cap per upload
  String _accessKey = generatePin();
  int _failedAttempts = 0;
  DateTime? _lockedUntil;
  static const int _maxAttempts = 5;
  static const Duration _lockFor = Duration(minutes: 5);

  /// Random per-session key. The portal URL shown to the user carries it as `?k=`;
  /// every request (page, file list, download, upload) must present it.
  String get accessKey => _accessKey;
  final List<SharedBrowserFile> _sharedFiles = [];
  final _receivedController = StreamController<TransferTask>.broadcast();

  Stream<TransferTask> get receivedFilesStream => _receivedController.stream;
  List<SharedBrowserFile> get sharedFiles => List.unmodifiable(_sharedFiles);
  bool get isRunning => _server != null;
  int? get port => _server?.port;

  void setSharedFiles(List<SharedBrowserFile> files) {
    _sharedFiles
      ..clear()
      ..addAll(files);
  }

  Future<int> start({int preferredPort = 8080}) async {
    await stop();
    _accessKey = generatePin();
    _failedAttempts = 0;
    _lockedUntil = null;
    final handler = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addHandler(_route);

    try {
      _server = await shelf_io.serve(
        handler,
        InternetAddress.anyIPv4,
        preferredPort,
      );
    } catch (_) {
      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 0);
    }
    return _server!.port;
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  static const Map<String, String> _secureHeaders = {
    'x-content-type-options': 'nosniff',
    'cache-control': 'no-store',
    'referrer-policy': 'no-referrer',
  };

  bool _isAuthorized(shelf.Request request) {
    final supplied =
        request.headers['x-vega-key'] ?? request.url.queryParameters['k'] ?? '';
    return constantTimeEquals(supplied, _accessKey);
  }

  Future<shelf.Response> _route(shelf.Request request) async {
    final path = request.url.path;

    if (!_isAuthorized(request)) {
      final supplied =
          request.headers['x-vega-key'] ?? request.url.queryParameters['k'] ?? '';
      final now = DateTime.now();
      final locked = _lockedUntil != null && now.isBefore(_lockedUntil!);
      var wrong = false;
      if (supplied.isNotEmpty && !locked) {
        wrong = true;
        _failedAttempts++;
        if (_failedAttempts >= _maxAttempts) {
          _lockedUntil = now.add(_lockFor);
          _failedAttempts = 0;
        }
      }
      if (request.method == 'GET' && path.isEmpty) {
        final nowLocked = _lockedUntil != null && now.isBefore(_lockedUntil!);
        return shelf.Response(
          nowLocked ? 429 : 200,
          body: _pinPageHtml(
            error: nowLocked
                ? 'Too many wrong attempts. Try again in a few minutes.'
                : (wrong ? 'Wrong PIN. Check the PIN shown in the Vega app.' : null),
          ),
          headers: {
            ..._secureHeaders,
            'content-type': 'text/html; charset=utf-8',
            'content-security-policy':
                "default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'",
          },
        );
      }
      return shelf.Response(
        401,
        body: 'PIN required. Open this address in a browser and enter the PIN shown in the Vega app.',
        headers: {..._secureHeaders, 'content-type': 'text/plain; charset=utf-8'},
      );
    }

    if (request.method == 'GET' && path.isEmpty) {
      return shelf.Response.ok(
        _portalHtml().replaceFirst('__VEGA_KEY__', _accessKey),
        headers: {
          ..._secureHeaders,
          'content-type': 'text/html; charset=utf-8',
          'content-security-policy':
              "default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'; img-src data:; base-uri 'none'; form-action 'none'",
        },
      );
    }

    if (request.method == 'GET' && path == 'api/files') {
      final list = _sharedFiles
          .map((f) => {'id': f.id, 'name': f.name, 'size': f.size})
          .toList();
      return shelf.Response.ok(
        jsonEncode(list),
        headers: {..._secureHeaders, 'content-type': 'application/json; charset=utf-8'},
      );
    }

    if (request.method == 'GET' && path.startsWith('download/')) {
      final id = path.substring('download/'.length);
      final match = _sharedFiles.where((f) => f.id == id).firstOrNull;
      if (match == null) {
        return shelf.Response.notFound('File not found');
      }
      final file = File(match.path);
      if (!await file.exists()) {
        return shelf.Response.notFound('Source file missing');
      }
      return shelf.Response.ok(
        file.openRead(),
        headers: {
          ..._secureHeaders,
          'content-type': 'application/octet-stream',
          'content-length': '${await file.length()}',
          'content-disposition': _contentDisposition(match.name),
        },
      );
    }

    if (request.method == 'POST' && path == 'api/upload') {
      final rawName = request.url.queryParameters['name'] ??
          'browser_upload_${DateTime.now().millisecondsSinceEpoch}';
      final safeName = sanitizeFileName(rawName, fallback: 'browser_upload');
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(p.join(tempDir.path, 'web_${randomHex(8)}_$safeName'));
      final sink = tempFile.openWrite();
      int totalWritten = 0;

      try {
        await for (final chunk in request.read()) {
          totalWritten += chunk.length;
          if (totalWritten > _maxUploadBytes) {
            throw const FileSystemException('Upload exceeds the maximum allowed size');
          }
          sink.add(chunk);
        }
        await sink.flush();
        await sink.close();
      } catch (_) {
        try {
          await sink.close();
        } catch (_) {}
        if (await tempFile.exists()) await tempFile.delete();
        return shelf.Response(
          400,
          body: jsonEncode({'ok': false, 'error': 'Upload failed'}),
          headers: {..._secureHeaders, 'content-type': 'application/json; charset=utf-8'},
        );
      }

      final savedPath = await PlatformBridge.saveToDownloads(
        sourcePath: tempFile.path,
        fileName: safeName,
      );
      if (savedPath != tempFile.path) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }

      if (!_receivedController.isClosed) {
        _receivedController.add(
          TransferTask(
            id: 'web-${DateTime.now().millisecondsSinceEpoch}',
            fileName: safeName,
            totalBytes: totalWritten,
            transferredBytes: totalWritten,
            direction: TransferDirection.receive,
            status: TransferStatus.completed,
            peerName: 'Browser Portal',
            // Browser uploads carry no hash, so they are never reported as verified.
            integrityVerified: false,
            encrypted: false,
            savedLocation: savedPath,
            updatedAt: DateTime.now(),
          ),
        );
      }

      return shelf.Response.ok(
        jsonEncode({'ok': true, 'savedTo': savedPath, 'bytes': totalWritten}),
        headers: {..._secureHeaders, 'content-type': 'application/json; charset=utf-8'},
      );
    }

    return shelf.Response.notFound('Not Found');
  }

  /// RFC 6266 header: ASCII fallback plus UTF-8 `filename*`, safe against quote/CRLF injection.
  static String _contentDisposition(String name) {
    final ascii = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return "attachment; filename=\"$ascii\"; filename*=UTF-8''${Uri.encodeComponent(name)}";
  }

  String _pinPageHtml({String? error}) {
    final msg = error == null
        ? ''
        : '<p class="e">${error.replaceAll('&', '&amp;').replaceAll('<', '&lt;')}</p>';
    return '''<!doctype html>
<html lang="en"><head><meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1" />
<title>Vega</title>
<style>
body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;background:#0A1F44;color:#fff;font-family:system-ui,sans-serif}
.c{width:min(340px,90vw);text-align:center}
h1{font-size:28px;margin:0 0 6px;letter-spacing:.14em}
p{color:#BFD6FF;font-size:14px}
.e{color:#FFB36B}
input{width:100%;box-sizing:border-box;font-size:30px;letter-spacing:.35em;text-align:center;padding:12px;border-radius:16px;border:1px solid #F5D08A;background:#0D2148;color:#fff;margin:12px 0}
button{width:100%;padding:14px;border-radius:999px;border:0;background:#E06D06;color:#fff;font-size:17px;font-weight:700;cursor:pointer}
</style></head><body><div class="c">
<h1>VEGA</h1><p>Enter the 6-digit PIN shown on the phone</p>$msg
<input id="p" inputmode="numeric" maxlength="6" autofocus autocomplete="off" />
<button id="b">Open</button></div>
<script>
function go(){var v=document.getElementById('p').value.replace(/\\D/g,'');if(v)location.href='/?k='+v;}
document.getElementById('b').onclick=go;
document.getElementById('p').onkeydown=function(e){if(e.key==='Enter')go();};
</script></body></html>''';
  }

  String _portalHtml() {
    return '''
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1" />
<title>Vega (वेग) • Offline Browser Share</title>
<style>
  * { box-sizing: border-box; }
  body { margin: 0; font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background: #06132B; color: #fff; min-height: 100vh; }
  .wrap { max-width: 720px; margin: 0 auto; padding: 28px 16px 56px; }
  .hero { background: linear-gradient(135deg, #0A1F44 0%, #003366 65%, #007AFF 100%); border: 1px solid rgba(197,160,89,.55); border-radius: 26px; padding: 24px; margin-bottom: 18px; box-shadow: 0 20px 50px rgba(0,0,0,.35); }
  h1 { margin: 0 0 6px; font-size: 22px; font-weight: 800; letter-spacing: .5px; }
  p { margin: 0; color: #DBEAFE; font-size: 13.5px; }
  .card { background: #0A1F44; border: 1px solid rgba(197,160,89,.4); border-radius: 24px; padding: 20px; margin-bottom: 16px; }
  h3 { margin: 0 0 12px; font-size: 16px; font-weight: 700; color: #E4C788; }
  .drop { border: 1.5px dashed rgba(197,160,89,.45); border-radius: 18px; padding: 22px 16px; text-align: center; background: #06132B; cursor: pointer; transition: border-color .15s, background .15s; }
  .drop.drag { border-color: #007AFF; background: rgba(0,122,255,.12); }
  .btn { display: inline-flex; align-items: center; justify-content: center; gap: 8px; background: #007AFF; color: #fff; border: 1px solid rgba(197,160,89,.65); border-radius: 14px; padding: 11px 22px; font-weight: 700; font-size: 14px; text-decoration: none; cursor: pointer; }
  .btn-blue { background: #003366; }
  .row { display: flex; justify-content: space-between; align-items: center; padding: 12px 14px; margin-bottom: 8px; border-radius: 16px; background: #06132B; border: 1px solid rgba(197,160,89,.35); gap: 12px; }
  .row:last-child { margin-bottom: 0; }
  .bar-wrap { height: 8px; border-radius: 999px; background: #06132B; overflow: hidden; margin-top: 12px; display: none; }
  .bar { height: 100%; width: 0%; background: linear-gradient(90deg, #007AFF, #C5A059); transition: width .12s; }
  #status { margin-top: 10px; font-size: 13px; color: #E4C788; font-family: ui-monospace, monospace; }
</style>
</head>
<body>
<div class="wrap">
  <div class="hero">
    <h1>Vega · वेग</h1>
    <p>Direct Offline Wi-Fi / Hotspot Portal · Manatwal Innovations</p>
  </div>
  <div class="card">
    <h3>Send Files from Windows / Browser to Phone</h3>
    <label class="drop" id="dropzone">
      <input type="file" id="picker" multiple style="display:none" />
      <div style="font-weight:700;margin-bottom:4px" id="picklabel">Click or drop files here to queue</div>
      <div style="font-size:12px;color:#93C5FD">Transfers over local Wi-Fi directly to Downloads/Vega</div>
    </label>
    <div style="margin-top:14px">
      <button class="btn" onclick="uploadFiles()">Upload to Device</button>
    </div>
    <div class="bar-wrap" id="barwrap"><div class="bar" id="bar"></div></div>
    <div id="status"></div>
  </div>
  <div class="card">
    <h3>Files Shared from Device</h3>
    <div id="list"><p style="color:#93C5FD">Checking available files...</p></div>
  </div>
</div>
<script>
const KEY = '__VEGA_KEY__';
const picker = document.getElementById('picker');
const dz = document.getElementById('dropzone');
const pickLabel = document.getElementById('picklabel');
picker.addEventListener('change', () => {
  pickLabel.textContent = picker.files.length ? picker.files.length + ' file(s) ready to upload' : 'Click or drop files here to queue';
});
dz.addEventListener('dragover', (e) => { e.preventDefault(); dz.classList.add('drag'); });
dz.addEventListener('dragleave', () => dz.classList.remove('drag'));
dz.addEventListener('drop', (e) => {
  e.preventDefault(); dz.classList.remove('drag');
  if (e.dataTransfer.files.length) {
    picker.files = e.dataTransfer.files;
    pickLabel.textContent = picker.files.length + ' file(s) ready to upload';
  }
});
function fmt(b) {
  if (b < 1024) return b + ' B';
  if (b < 1048576) return (b / 1024).toFixed(1) + ' KB';
  if (b < 1073741824) return (b / 1048576).toFixed(1) + ' MB';
  return (b / 1073741824).toFixed(2) + ' GB';
}
async function refresh() {
  try {
    const res = await fetch('/api/files?k=' + encodeURIComponent(KEY), { headers: { 'x-vega-key': KEY } });
    if (!res.ok) return;
    const files = await res.json();
    const list = document.getElementById('list');
    list.textContent = '';
    if (!files.length) {
      const p = document.createElement('p');
      p.style.color = '#93C5FD';
      p.textContent = 'No files selected on the host device yet.';
      list.appendChild(p);
      return;
    }
    for (const f of files) {
      const row = document.createElement('div');
      row.className = 'row';
      const info = document.createElement('div');
      info.style.minWidth = '0';
      const nm = document.createElement('div');
      nm.style.cssText = 'font-weight:700;white-space:nowrap;overflow:hidden;text-overflow:ellipsis';
      nm.textContent = String(f.name);
      const sz = document.createElement('div');
      sz.style.cssText = 'font-size:12px;color:#93C5FD';
      sz.textContent = fmt(Number(f.size) || 0);
      info.appendChild(nm);
      info.appendChild(sz);
      const a = document.createElement('a');
      a.className = 'btn btn-blue';
      a.textContent = 'Download';
      a.href = '/download/' + encodeURIComponent(f.id) + '?k=' + encodeURIComponent(KEY);
      row.appendChild(info);
      row.appendChild(a);
      list.appendChild(row);
    }
  } catch (_) {}
}
function uploadOne(file, idx, total, bar, st) {
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.open('POST', '/api/upload?k=' + encodeURIComponent(KEY) + '&name=' + encodeURIComponent(file.name));
    xhr.setRequestHeader('x-vega-key', KEY);
    xhr.upload.onprogress = (ev) => {
      if (ev.lengthComputable) {
        const pct = Math.round((ev.loaded / ev.total) * 100);
        bar.style.width = pct + '%';
        st.textContent = '(' + (idx + 1) + '/' + total + ') ' + file.name + ' — ' + pct + '%';
      }
    };
    xhr.onload = () => xhr.status >= 200 && xhr.status < 300 ? resolve() : reject(new Error('HTTP ' + xhr.status));
    xhr.onerror = () => reject(new Error('Network error'));
    xhr.send(file);
  });
}
async function uploadFiles() {
  const files = picker.files;
  const st = document.getElementById('status');
  const bw = document.getElementById('barwrap');
  const bar = document.getElementById('bar');
  if (!files.length) { st.textContent = 'Select at least one file first.'; return; }
  bw.style.display = 'block';
  try {
    for (let i = 0; i < files.length; i++) {
      await uploadOne(files[i], i, files.length, bar, st);
    }
    bar.style.width = '100%';
    st.textContent = 'Done! ' + files.length + ' file(s) saved to Downloads/Vega.';
  } catch (err) {
    st.textContent = 'Upload failed: ' + err.message;
  }
}
refresh();
setInterval(refresh, 4000);
</script>
</body>
</html>
''';
  }

  Future<void> dispose() async {
    await stop();
    await _receivedController.close();
  }
}

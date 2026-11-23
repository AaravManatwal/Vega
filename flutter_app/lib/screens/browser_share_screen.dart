import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import '../core/browser_share_server.dart';
import '../models/transfer_models.dart';
import '../state/app_state.dart';
import '../l10n/vega_strings.dart';
import '../widgets/heritage/heritage_page.dart';
import '../widgets/heritage/heritage_palette.dart';
import '../widgets/heritage/heritage_panel.dart';
import '../widgets/heritage/saffron_button.dart';

class BrowserShareScreen extends ConsumerStatefulWidget {
  const BrowserShareScreen({super.key});

  @override
  ConsumerState<BrowserShareScreen> createState() => _BrowserShareScreenState();
}

class _BrowserShareScreenState extends ConsumerState<BrowserShareScreen> {
  final List<SharedBrowserFile> _files = [];

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null) return;
    setState(() {
      for (final f in result.files) {
        if (f.path != null) {
          _files.add(
            SharedBrowserFile(
              id: const Uuid().v4(),
              name: f.name,
              path: f.path!,
              size: f.size,
            ),
          );
        }
      }
    });
    ref.read(vegaProvider.notifier).updateSharedBrowserFiles(_files);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vegaProvider);
    final controller = ref.read(vegaProvider.notifier);
    final s = VegaStrings(state.settings.isHindi);
    final p = HeritagePalette.of(context);
    final ip = state.localIps.isNotEmpty ? state.localIps.first : '127.0.0.1';
    final port = state.browserPortalPort ?? 8080;
    final url = 'http://$ip:$port/?k=${controller.browserServer.accessKey}';
    final running = state.isBrowserPortalRunning;

    return HeritagePage(
      title: s.t('Browser & Windows Share', 'ब्राउज़र और विंडोज़ शेयर'),
      subtitle: s.t('No install needed, over local Wi-Fi', 'बिना इंस्टॉल, लोकल Wi-Fi पर'),
      child: ListView(
        children: [
          HeritagePanel(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  s.t(
                    'Open this address in a browser on Windows, Mac or Linux, on the same Wi-Fi or hotspot:',
                    'इसी Wi-Fi या हॉटस्पॉट पर Windows, Mac या Linux के ब्राउज़र में यह पता खोलें:',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.textMuted, fontSize: 13.5, height: 1.4),
                ),
                const SizedBox(height: 14),
                if (running) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: QrImageView(data: url, size: 180),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: url));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(s.t('Address copied', 'पता कॉपी हुआ'))),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: p.field,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: p.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              url,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: p.text,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.copy_rounded, size: 16, color: p.accentText),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (running)
                  OutlinedButton.icon(
                    onPressed: () => controller.toggleBrowserPortal(_files),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      foregroundColor: p.text,
                      side: BorderSide(color: p.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                    ),
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: Text(s.t('Stop sharing', 'शेयरिंग बंद करें'),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  )
                else
                  SaffronButton(
                    label: s.t('Start sharing', 'शेयरिंग शुरू करें'),
                    icon: Icons.play_arrow_rounded,
                    onPressed: () => controller.toggleBrowserPortal(_files),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          HeritagePanel(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.t('Shared to browser (${_files.length})',
                            'ब्राउज़र पर शेयर (${_files.length})'),
                        style: TextStyle(
                            color: p.text, fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: p.accentText),
                      onPressed: _pickFiles,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(s.t('Add files', 'फ़ाइलें जोड़ें')),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_files.isEmpty)
                  Text(
                    s.t(
                      'Add files from this phone to download them in the PC browser. Files uploaded from the PC are saved to Downloads/Vega.',
                      'इस फ़ोन की फ़ाइलें जोड़ें ताकि PC के ब्राउज़र से डाउनलोड हो सकें। PC से भेजी गई फ़ाइलें Downloads/Vega में सेव होती हैं।',
                    ),
                    style: TextStyle(fontSize: 13, color: p.textMuted, height: 1.4),
                  )
                else
                  ..._files.map(
                    (f) => Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: p.tile,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: p.softBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.insert_drive_file_outlined, color: p.accentText),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  f.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: p.text, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  formatBytes(f.size),
                                  style: TextStyle(color: p.textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

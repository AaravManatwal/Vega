import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import '../core/browser_share_server.dart';
import '../models/transfer_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

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
    final ip = state.localIps.isNotEmpty ? state.localIps.first : '127.0.0.1';
    final port = state.browserPortalPort ?? 8080;
    final url = 'http://$ip:$port/?k=${controller.browserServer.accessKey}';

    return Scaffold(
      backgroundColor: VegaColors.deepCanvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
          children: [
            Container(
              padding: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: VegaColors.sandstoneGold.withValues(alpha: 0.35),
                  ),
                ),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: VegaColors.midnightBlue,
                        border: Border.all(
                          color: VegaColors.sandstoneGold.withValues(alpha: 0.55),
                        ),
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Browser & Windows Share',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Zero-install local Wi-Fi transfer portal',
                          style: TextStyle(
                            color: VegaColors.goldHighlight,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: VegaColors.deepNavy,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: VegaColors.sandstoneGold.withValues(alpha: 0.48),
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'Open this URL in Windows, Mac, or Linux Browser on the same Wi-Fi / Hotspot:',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: VegaColors.lightSky,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (state.isBrowserPortalRunning) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: QrImageView(data: url, size: 180),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: url));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Copied $url')),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: VegaColors.deepCanvas,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: VegaColors.electricBlue
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              url,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.copy_rounded,
                              size: 16,
                              color: VegaColors.lightSky,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: state.isBrowserPortalRunning
                            ? VegaColors.error
                            : VegaColors.electricBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: () => controller.toggleBrowserPortal(_files),
                      icon: Icon(
                        state.isBrowserPortalRunning
                            ? Icons.stop_circle_outlined
                            : Icons.play_arrow_rounded,
                      ),
                      label: Text(
                        state.isBrowserPortalRunning
                            ? 'Stop Browser Portal'
                            : 'Start Browser Portal',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: VegaColors.deepNavy,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: VegaColors.sandstoneGold.withValues(alpha: 0.45),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Shared to Browser (${_files.length})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: VegaColors.electricBlue,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _pickFiles,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Select Files'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_files.isEmpty)
                    const Text(
                      'Select files from your phone to make them downloadable in the PC browser. Uploads from PC also save automatically to Downloads/Vega.',
                      style: TextStyle(
                        fontSize: 13,
                        color: VegaColors.lightSky,
                      ),
                    )
                  else
                    ..._files.map(
                      (f) => Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: VegaColors.deepCanvas,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: VegaColors.borderMidnight,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.insert_drive_file_outlined,
                              color: VegaColors.goldHighlight,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    f.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    formatBytes(f.size),
                                    style: const TextStyle(
                                      color: VegaColors.lightSky,
                                      fontSize: 12,
                                    ),
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
      ),
    );
  }
}

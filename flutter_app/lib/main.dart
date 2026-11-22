import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/transfer_engine.dart';
import 'screens/splash_screen.dart';
import 'services/foreground_service.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'widgets/approval/approval_host.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  TransferEngine.enableHardwareCrypto();
  ForegroundTransferService.init();
  runApp(const ProviderScope(child: VegaApp()));
}

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> _messengerKey =
    GlobalKey<ScaffoldMessengerState>();

class VegaApp extends ConsumerWidget {
  const VegaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final darkMode = ref.watch(vegaProvider).settings.darkMode;

    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      builder: (context, child) => ApprovalHost(
        navigatorKey: _navigatorKey,
        messengerKey: _messengerKey,
        child: child ?? const SizedBox.shrink(),
      ),
      title: 'Vega',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      home: const VegaSplashScreen(),
    );
  }
}

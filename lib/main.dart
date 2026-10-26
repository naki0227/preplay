import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // Required for Colors
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'state/app_state.dart';
import 'ui/home_screen.dart';
import 'theme/app_colors.dart';
import 'config/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    final ofl = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['M PLUS Rounded 1c'], ofl);
  });
  if (AppConfig.hasSupabase) {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
      );
    } catch (e) {
      print("Supabase init failed: $e");
      // Proceed without Cloud features
    }
  } else {
    print('SUPABASE_URL / SUPABASE_ANON_KEY not set. Community features disabled.');
  }
  
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent, // Android
    statusBarIconBrightness: Brightness.dark, // Android
    statusBarBrightness: Brightness.light, // iOS (Light background -> Dark icons)
  ));
  runApp(const PreplayApp());
}

class PreplayApp extends StatelessWidget {
  const PreplayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PreplayController(),
      child: const CupertinoApp(
        title: 'Preplay',
        theme: CupertinoThemeData(
          brightness: Brightness.light, 
          // Auto-brightness is handled by system, but explicit defaults help
        ),
        home: HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

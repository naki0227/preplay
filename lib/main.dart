import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';
import 'state/app_state.dart';
import 'ui/home_screen.dart';
import 'theme/app_colors.dart';
import 'services/ai_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
    AiService().init();
  } catch (e) {
    print("Env load failed: $e");
    // Proceed without AI (MVP fallback)
  }
  
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
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

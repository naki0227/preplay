import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'state/app_state.dart';
import 'ui/home_screen.dart';

void main() {
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

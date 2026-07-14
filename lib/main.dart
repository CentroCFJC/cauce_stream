import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const CauceStreamApp());
}

class CauceStreamApp extends StatelessWidget {
  const CauceStreamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: MaterialApp(
        title: 'CAUCE Stream',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0A1628),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF1565C0),
            surface: Color(0xFF0D1D34),
          ),
          useMaterial3: true,
          focusColor: Colors.white,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

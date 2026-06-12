/// VPN2GO — main.dart — точка входа
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Портретный режим
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  
  // Стиль системных панелей
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppTheme.bgDark,
  ));
  
  runApp(const Vpn2GoApp());
}

class Vpn2GoApp extends StatefulWidget {
  const Vpn2GoApp({super.key});

  @override
  State<Vpn2GoApp> createState() => _Vpn2GoAppState();
}

class _Vpn2GoAppState extends State<Vpn2GoApp> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final hasSession = await _api.restoreSession();
    setState(() {
      _isLoggedIn = hasSession;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          backgroundColor: AppTheme.bgDark,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.vpn_key_rounded, size: 64, color: AppTheme.primary),
                SizedBox(height: 16),
                Text('VPN2GO', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                SizedBox(height: 24),
                CircularProgressIndicator(color: AppTheme.primary),
              ],
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'VPN2GO',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: _isLoggedIn ? '/home' : '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/profile': (context) => const _ProfileScreen(),
        '/register': (context) => const _RegisterScreen(),
      },
    );
  }
}

// === Заглушки для экранов (реализуем позже) ===

class _ProfileScreen extends StatelessWidget {
  const _ProfileScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: const Center(child: Text('Профиль — TODO', style: TextStyle(fontSize: 18))),
    );
  }
}

class _RegisterScreen extends StatelessWidget {
  const _RegisterScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация')),
      body: const Center(child: Text('Регистрация — TODO', style: TextStyle(fontSize: 18))),
    );
  }
}

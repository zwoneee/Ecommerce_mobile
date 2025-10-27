// lib/main.dart
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/api_service.dart';
import 'services/signalr_service.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'screens/product_list_screen.dart';
import 'screens/login_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/register_screen.dart';

Future<void> main() async {
  // Make zone errors non-fatal during dev if you prefer:
  // BindingBase.debugZoneErrorsAreFatal = true; // only if you want fatal

  // Use runZonedGuarded and CALL ensureInitialized inside it so both are in same zone
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    final baseUrl = kIsWeb ? 'https://localhost:7068' : 'http://10.0.2.2:5106';
    final api = ApiService(baseUrl: baseUrl);
    final signalR = SignalRService(api: api);

    // Optional: print baseUrl so you can verify which one is used
    // ignore: avoid_print
    print('Main: baseUrl=$baseUrl');

    runApp(
      MultiProvider(
        providers: [
          Provider<ApiService>.value(value: api),
          Provider<SignalRService>.value(value: signalR),
          ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider(api: api, signalR: signalR)),
          ChangeNotifierProvider<CartProvider>(create: (_) => CartProvider(api: api)),
        ],
        child: const MyApp(),
      ),
    );
  }, (error, stack) {
    // global uncaught errors
    // ignore: avoid_print
    print('Uncaught zone error: $error\n$stack');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ecommerce Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ProductListScreen(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/chat': (_) => const ChatScreen(),
        '/products': (_) => const ProductListScreen(),
      },
    );
  }
}

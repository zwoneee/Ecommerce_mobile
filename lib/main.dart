// lib/main.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/api_service.dart';
import 'services/signalr_service.dart';

// Providers (nếu bạn đã có các file này, giữ nguyên import)
// Nếu bạn chưa có thì tạo theo mẫu ChangeNotifier (AuthProvider/CartProvider)
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';

// Screens
import 'screens/product_list_screen.dart';
import 'screens/login_screen.dart';
import 'screens/chat_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Chọn baseUrl phù hợp cho web / mobile emulator
  final baseUrl = kIsWeb ? 'https://localhost:7068' : 'http://10.0.2.2:5106';

  final api = ApiService(baseUrl: baseUrl);
  final signalR = SignalRService(api: api);

  // trong main.dart — phần MultiProvider (chỉ minh họa phần providers)
  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>.value(value: api),
        Provider<SignalRService>.value(value: signalR),
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider(api: api, signalR: signalR)),
        // <-- pass api here:
        ChangeNotifierProvider<CartProvider>(create: (_) => CartProvider(api: api)),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ecommerce Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: false,
      ),

      // home mặc định là product list
      home: const ProductListScreen(),

      // một số route cơ bản
      routes: {
        '/login': (_) => const LoginScreen(),
        '/chat': (_) => const ChatScreen(),
        '/products': (_) => const ProductListScreen(),
      },
    );
  }
}

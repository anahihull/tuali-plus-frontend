import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:english_words/english_words.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'home.dart';
import 'login.dart';
import 'signup.dart';
import 'dashboard.dart';
import 'record.dart';
import 'report.dart';
import 'map.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const MyApp());
}

class MyAppState extends ChangeNotifier {
  var current = WordPair.random();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: MaterialApp(
        title: 'Tuali++',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        ),
        initialRoute: '/',
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/':
              return MaterialPageRoute(builder: (_) => const SessionWrapper());
            case '/login':
              return MaterialPageRoute(builder: (_) => const Login());
            case '/signup':
              return MaterialPageRoute(builder: (_) => const SignUp());
            case '/dashboard':
              final args = settings.arguments as Map<String, dynamic>;
              return MaterialPageRoute(
                builder: (_) => Dashboard(
                  storeId: args['id'],
                  direccion: args['direccion'],
                  userId: '${Supabase.instance.client.auth.currentUser?.id}',
                ),
              );
            case '/record':
              return MaterialPageRoute(
                builder: (context) {
                  final args = settings.arguments as Map<String, dynamic>;
                  return Record(
                    storeId: args['id'],
                    userId: '${Supabase.instance.client.auth.currentUser?.id}',
                  );
                },
              );
            case '/report':
              return MaterialPageRoute(builder: (_) => const Report());
            case '/map':
              return MaterialPageRoute(builder: (_) => StoreMap(userId: '${Supabase.instance.client.auth.currentUser?.id}'));
            default:
              return MaterialPageRoute(
                builder: (_) => const Scaffold(
                  body: Center(child: Text('Ruta no encontrada')),
                ),
              );
          }
        },
      ),
    );
  }
}

class SessionWrapper extends StatelessWidget {
  const SessionWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;


    if (session != null) {
      // ✅ Usuario loggeado → ir al mapa
      return StoreMap(userId: '${Supabase.instance.client.auth.currentUser?.id}');
    }

    // ❌ No hay sesión → mostrar login
    return const Login();
  }
}

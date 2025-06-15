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
        routes: {
          '/': (context) => Home(),
          '/login': (context) => const Login(),
          '/signup': (context) => const SignUp(),
          '/dashboard': (context) => const Dashboard(),
          '/record': (context) => const Record(),
          '/report': (context) => const Report(),
        },
      ),
    );
  }
}

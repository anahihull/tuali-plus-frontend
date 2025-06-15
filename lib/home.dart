import 'package:flutter/material.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('This is the home page!'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              child: const Text('Go to Login'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/signup'),
              child: const Text('Go to Signup'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/dashboard',),
              child: const Text('Go to Dashboard'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/record'),
              child: const Text('Go to Record'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/report'),
              child: const Text('Go to Report'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/map'),
              child: const Text('Go to Map'),
            ),
          ],
        ),
      ),
    );
  }
}

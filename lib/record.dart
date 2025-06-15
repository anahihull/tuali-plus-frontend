import 'package:flutter/material.dart';

class Record extends StatelessWidget {
  const Record({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Record')),
      body: Center(
        child: Text('This is the Record page!'),
      ),
    );
  }
}

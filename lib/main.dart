import 'package:flutter/material.dart';

import 'ui/theme.dart';

void main() => runApp(const BeerCountApp());

class BeerCountApp extends StatelessWidget {
  const BeerCountApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Beer Count',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const Scaffold(body: SizedBox.shrink()),
      );
}

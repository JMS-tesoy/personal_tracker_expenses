import 'package:flutter/material.dart';
import 'main_navigation.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Payday Tracker',
      debugShowCheckedModeBanner: false,
      home: const MainNavigation(),
    );
  }
}
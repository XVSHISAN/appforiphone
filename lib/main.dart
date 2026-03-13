import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/connection_screen.dart';
import 'services/ble_service.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => BleService(),
      child: const MiniArmApp(),
    ),
  );
}

class MiniArmApp extends StatelessWidget {
  const MiniArmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MiniArm',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const InitialPermissionScreen(),
    );
  }
}

class InitialPermissionScreen extends StatefulWidget {
  const InitialPermissionScreen({super.key});

  @override
  State<InitialPermissionScreen> createState() => _InitialPermissionScreenState();
}

class _InitialPermissionScreenState extends State<InitialPermissionScreen> {
  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await [
        Permission.location,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();
    }
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ConnectionScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在请求蓝牙与定位权限...'),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import '../services/ble_service.dart';
import 'control_screen.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<BleService>().startScan();
    });
  }

  void _connect(BluetoothDevice device) async {
    final bleService = context.read<BleService>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text("连接中..."),
          ],
        ),
      ),
    );

    try {
      await bleService.connectToDevice(device);
      if (mounted) {
        Navigator.pop(context); // Close dialog
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ControlScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('连接失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bleService = context.watch<BleService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('设备连接'),
        actions: [
          IconButton(
            icon: Icon(bleService.isScanning ? Icons.stop : Icons.refresh),
            onPressed: () {
              if (bleService.isScanning) {
                bleService.stopScan();
              } else {
                bleService.startScan();
              }
            },
          )
        ],
      ),
      body: bleService.scanResults.isEmpty
          ? const Center(child: Text("未找到设备，请点击右上角刷新"))
          : ListView.builder(
              itemCount: bleService.scanResults.length,
              itemBuilder: (context, index) {
                final result = bleService.scanResults[index];
                final device = result.device;
                return ListTile(
                  title: Text(device.platformName.isNotEmpty ? device.platformName : "未知设备"),
                  subtitle: Text(device.remoteId.str),
                  trailing: ElevatedButton(
                    onPressed: () => _connect(device),
                    child: const Text('连接'),
                  ),
                );
              },
            ),
    );
  }
}

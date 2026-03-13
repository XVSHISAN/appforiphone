import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ble_service.dart';
import 'control_screen.dart' as import_control;

class MoveScreen extends StatefulWidget {
  const MoveScreen({super.key});

  @override
  State<MoveScreen> createState() => _MoveScreenState();
}

class _MoveScreenState extends State<MoveScreen> {
  int moveX = 0;
  int moveY = 0;
  int moveZ = 0;

  void _sendMoveCmd() {
    final bytes = [0xA5, 0xA5, 0x02, _toSignedByte(moveX), _toSignedByte(moveY), _toSignedByte(moveZ)];
    context.read<BleService>().sendCommand(bytes);
  }

  int _toSignedByte(int value) {
    return value < 0 ? (256 + value) : value; // Two's complement representation if needed by the peripheral.
  }

  void _sendResetCmd() {
    final bytes = [0xA5, 0xA5, 0x01, 90, 40, 130, 0, 0];
    context.read<BleService>().sendCommand(bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('微调操作'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const import_control.ControlScreen()));
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _sendResetCmd,
            tooltip: '复位',
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildHoldButton("前进 (X-)", () => moveX = -1, () => moveX = 0),
                _buildHoldButton("后退 (X+)", () => moveX = 1, () => moveX = 0),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildHoldButton("左移 (Z+)", () => moveZ = 1, () => moveZ = 0),
                _buildHoldButton("右移 (Z-)", () => moveZ = -1, () => moveZ = 0),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildHoldButton("上升 (Y+)", () => moveY = 1, () => moveY = 0),
                _buildHoldButton("下降 (Y-)", () => moveY = -1, () => moveY = 0),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHoldButton(String label, VoidCallback onPressDown, VoidCallback onPressUp) {
    return GestureDetector(
      onTapDown: (_) {
        onPressDown();
        _sendMoveCmd();
      },
      onTapUp: (_) {
        onPressUp();
        _sendMoveCmd();
      },
      onTapCancel: () {
        onPressUp();
        _sendMoveCmd();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

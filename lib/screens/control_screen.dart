import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ble_service.dart';
import 'move_screen.dart';

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  // ==================== 关节角度范围常量 ====================
  // 来自 Dolphin_Docs/03 和 have_ble_2 固件 check_angle()
  static const int seek1Min = 0, seek1Max = 180;   // A轴(旋转)
  static const int seek2Min = 0, seek2Max = 80;    // B轴(主臂仰俯) 实际上限85, APP端用80
  static const int seek4Min = 0, seek4Max = 37;    // G轴(夹爪)

  int seek1Val = 90;   // A轴
  int seek2Val = 0;    // B轴
  int seek3Min = 55, seek3Max = 180, seek3Val = 180;  // C轴(副臂)
  int seek4Val = 0;    // G轴

  bool _isPlayingTrajectory = false; // 轨迹播放锁，防止重复触发

  @override
  void initState() {
    super.initState();
    _initValues();
  }

  // 仅重置 UI 状态值，不发包（用于初始化）
  void _initValues() {
    seek1Val = 90;
    seek2Val = seek2Min;
    seek3Max = 180;
    seek3Val = seek3Max;
    seek3Min = 55;
    seek4Val = seek4Min;
  }

  // 重置到初始姿态并发送蓝牙指令（按钮触发）
  void _resetValues() {
    setState(() {
      seek1Val = 90;
      seek2Val = seek2Min;
      seek3Max = 180;
      seek3Val = seek3Max;
      seek3Min = 55;
      seek4Val = seek4Min;
    });
    _sendCtlCmd();
  }

  void _custom1() {
    setState(() {
      seek1Val = 130;
      seek2Val = 50;
      _updateSeek3Limits(seek2Val);
      seek3Val = 130;
      seek4Val = 0;
    });
    _sendCtlCmd();
  }

  void _custom2() {
    setState(() {
      seek1Val = 100;
      seek2Val = 60;
      _updateSeek3Limits(seek2Val);
      seek3Val = 120;
      seek4Val = 15;
    });
    _sendCtlCmd();
  }

  void _custom3() {
    setState(() {
      seek1Val = 50;
      seek2Val = 50;
      _updateSeek3Limits(seek2Val);
      seek3Val = 125;
      seek4Val = 35;
    });
    _sendCtlCmd();
  }

  // 注意：当在 setState 内部被调用时，不需要再套 setState
  void _updateSeek3Limits(int b) {
    seek3Min = 140 - b;
    int countMin = 196 - b;
    seek3Max = countMin <= 180 ? countMin : 180;
    if (seek3Val > seek3Max) seek3Val = seek3Max;
    if (seek3Val < seek3Min) seek3Val = seek3Min;
  }

  // ==================== BLE 协议发包 ====================
  // 模式一：直接角度规划 A5 A5 01 [A] [B] [C] [G] [0x00]
  // 参考 Dolphin_Docs/05 §2.1
  void _sendCtlCmd() {
    final bytes = [
      0xA5, 0xA5, 0x01,
      seek1Val & 0xFF,
      seek2Val & 0xFF,
      seek3Val & 0xFF,
      seek4Val & 0xFF,
      0x00, // 保留位
    ];
    context.read<BleService>().sendCommand(bytes);
  }

  // 发送指定角度的控制指令（用于轨迹播放），附带蓝牙连接安全检查
  void _sendAngles(int a, int b, int c, int g) {
    // 假如突然断开，避免往空的特征值发送导致崩溃
    if (context.read<BleService>().writeCharacteristic == null) return;
    
    final bytes = [
      0xA5, 0xA5, 0x01,
      a & 0xFF, b & 0xFF, c & 0xFF, g & 0xFF, 0x00,
    ];
    context.read<BleService>().sendCommand(bytes);
  }

  // ==================== 轨迹动作 ====================
  // 通用轨迹执行器：按顺序发送路径点，每两点间等待 interval
  Future<void> _playTrajectory(List<List<int>> waypoints, {int intervalMs = 800}) async {
    if (_isPlayingTrajectory || !mounted) return;
    setState(() => _isPlayingTrajectory = true);

    try {
      for (var wp in waypoints) {
        if (!mounted) break; // 组件销毁（如按返回键）
        
        // 每次发包前检查底层连接是否存活
        final bleService = context.read<BleService>();
        if (bleService.writeCharacteristic == null) {
          debugPrint("Trajectory aborted: BLE disconnected.");
          break;
        }

        _sendAngles(wp[0], wp[1], wp[2], wp[3]);
        
        if (!mounted) break;
        setState(() {
          seek1Val = wp[0];
          seek2Val = wp[1];
          seek3Val = wp[2];
          seek4Val = wp[3];
          _updateSeek3Limits(seek2Val);
        });
        
        await Future.delayed(Duration(milliseconds: intervalMs));
      }
    } finally {
      // 使用 finally 确保就算发生异常，标志位也能释放
      if (mounted) {
        setState(() => _isPlayingTrajectory = false);
      }
    }
  }

  // 三角形轨迹：3 顶点循环
  // 约束验证：
  //   P1(90,30,140) -> C_min=110, C_max=166 ✓
  //   P2(80,50,120) -> C_min=90,  C_max=146 ✓
  //   P3(100,50,120)-> C_min=90,  C_max=146 ✓
  void _playTriangle() {
    _playTrajectory([
      [90, 30, 140, 0],   // P1 顶部
      [80, 50, 120, 0],   // P2 左下
      [100, 50, 120, 0],  // P3 右下
      [90, 30, 140, 0],   // 回到 P1
    ]);
  }

  // 正方形轨迹：4 顶点循环
  // 约束验证：
  //   P1(80,30,140)  -> C_min=110, C_max=166 ✓
  //   P2(100,30,140) -> C_min=110, C_max=166 ✓
  //   P3(100,50,120) -> C_min=90,  C_max=146 ✓
  //   P4(80,50,120)  -> C_min=90,  C_max=146 ✓
  void _playSquare() {
    _playTrajectory([
      [80, 30, 140, 0],   // P1 左上
      [100, 30, 140, 0],  // P2 右上
      [100, 50, 120, 0],  // P3 右下
      [80, 50, 120, 0],   // P4 左下
      [80, 30, 140, 0],   // 回到 P1
    ]);
  }

  // 圆形轨迹：8 个采样点近似圆
  // 中心 A=90, B=40, C=130, 半径 ΔA=10, ΔB=10
  // 约束验证：B 范围 30~50, C 范围 120~140
  //   B=30 时 C_min=110, C_max=166 -> C=140 ✓
  //   B=40 时 C_min=100, C_max=156 -> C=130 ✓
  //   B=50 时 C_min=90,  C_max=146 -> C=120 ✓
  void _playCircle() {
    const int centerA = 90, centerB = 40, centerC = 130;
    const int radiusA = 10, radiusB = 10;
    const int samples = 8;
    List<List<int>> waypoints = [];

    for (int i = 0; i <= samples; i++) {
      double angle = (2 * pi * i) / samples;
      int a = centerA + (radiusA * cos(angle)).round();
      int b = centerB + (radiusB * sin(angle)).round();
      // C 轴联动：保持与 B 轴的几何关系 C ≈ 170 - B
      int c = centerC + (radiusB * -sin(angle)).round(); // B 升则 C 降
      waypoints.add([a, b, c, 0]);
    }

    _playTrajectory(waypoints);
  }

  // ==================== UI 构建 ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设备控制'),
        actions: [
          IconButton(
            icon: const Icon(Icons.gamepad),
            onPressed: _isPlayingTrajectory ? null : () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MoveScreen()));
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 第一行：复位和预设姿态按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isPlayingTrajectory ? null : _resetValues,
                  child: const Text('复位'),
                ),
                ElevatedButton(
                  onPressed: _isPlayingTrajectory ? null : _custom1,
                  child: const Text('姿态1'),
                ),
                ElevatedButton(
                  onPressed: _isPlayingTrajectory ? null : _custom2,
                  child: const Text('姿态2'),
                ),
                ElevatedButton(
                  onPressed: _isPlayingTrajectory ? null : _custom3,
                  child: const Text('姿态3'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 第二行：轨迹动作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _isPlayingTrajectory ? null : _playTriangle,
                  icon: const Icon(Icons.change_history),
                  label: const Text('三角形'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isPlayingTrajectory ? null : _playSquare,
                  icon: const Icon(Icons.crop_square),
                  label: const Text('正方形'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isPlayingTrajectory ? null : _playCircle,
                  icon: const Icon(Icons.circle_outlined),
                  label: const Text('圆形'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            if (_isPlayingTrajectory) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
              const SizedBox(height: 4),
              const Text('正在执行轨迹...', style: TextStyle(color: Colors.grey)),
            ],

            const SizedBox(height: 20),

            // 4 个滑块（移除了直线轴）
            _buildSliderRow("旋转范围 $seek1Min°-$seek1Max°", seek1Val, seek1Min, seek1Max, (v) {
              setState(() => seek1Val = v.toInt());
            }, (v) => _sendCtlCmd()),

            _buildSliderRow("B轴范围 $seek2Min°-$seek2Max°", seek2Val, seek2Min, seek2Max, (v) {
              setState(() {
                seek2Val = v.toInt();
                _updateSeek3Limits(seek2Val);
              });
            }, (v) => _sendCtlCmd()),

            _buildSliderRow("C轴范围 $seek3Min°-$seek3Max°", seek3Val, seek3Min, seek3Max, (v) {
              setState(() => seek3Val = v.toInt());
            }, (v) => _sendCtlCmd()),

            _buildSliderRow("夹爪范围 $seek4Min°-$seek4Max°", seek4Val, seek4Min, seek4Max, (v) {
              setState(() => seek4Val = v.toInt());
            }, (v) => _sendCtlCmd()),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderRow(String label, int value, int min, int max, ValueChanged<double> onChanged, ValueChanged<double> onChangeEnd) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text("$value°", style: const TextStyle(color: Colors.blue)),
            ],
          ),
          Slider(
            value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
            min: min.toDouble(),
            max: max.toDouble(),
            onChanged: _isPlayingTrajectory ? null : onChanged,
            onChangeEnd: _isPlayingTrajectory ? null : onChangeEnd,
          ),
        ],
      ),
    );
  }
}

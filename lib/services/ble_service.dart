import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleService extends ChangeNotifier {
  static const String customServiceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String customCharacteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  List<ScanResult> scanResults = [];
  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? writeCharacteristic;
  bool isScanning = false;
  int deviceMtu = 23;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<bool>? _isScanningSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;

  BleService() {
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      scanResults = results.where((r) => r.device.platformName.isNotEmpty).toList();
      notifyListeners();
    });

    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      isScanning = state;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _isScanningSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  Future<void> startScan() async {
    scanResults.clear();
    notifyListeners();
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    await stopScan();
    try {
      await device.connect(autoConnect: false);
      connectedDevice = device;
      
      try {
        if (defaultTargetPlatform == TargetPlatform.android) {
          await device.requestMtu(250);
        }
        deviceMtu = await device.mtu.first;
      } catch (e) {
        debugPrint("MTU Request failed: $e");
      }

      await _discoverServices(device);
      
      // 取消旧的连接状态监听，防止重连时累积多个监听器
      await _connectionSubscription?.cancel();
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          connectedDevice = null;
          writeCharacteristic = null;
          notifyListeners();
        }
      });
      notifyListeners();
    } catch (e) {
      debugPrint("Connect Error: $e");
      connectedDevice = null;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _discoverServices(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    for (var service in services) {
      if (service.uuid.toString().toLowerCase() == customServiceUuid) {
        for (var char in service.characteristics) {
          if (char.uuid.toString().toLowerCase() == customCharacteristicUuid) {
            writeCharacteristic = char;
            if (char.properties.notify || char.properties.indicate) {
              await char.setNotifyValue(true);
              char.onValueReceived.listen((value) {
                debugPrint("Notify: $value");
              });
            }
            break;
          }
        }
      }
    }
  }

  Future<void> disconnect() async {
    await connectedDevice?.disconnect();
    connectedDevice = null;
    writeCharacteristic = null;
    notifyListeners();
  }

  Future<void> sendCommand(List<int> bytes) async {
    if (writeCharacteristic != null) {
      try {
        await writeCharacteristic!.write(bytes, withoutResponse: false);
      } catch (e) {
        debugPrint("Write Error: $e");
      }
    }
  }
}

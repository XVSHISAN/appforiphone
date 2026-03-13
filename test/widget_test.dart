// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:appforiphone/main.dart';

void main() {
  testWidgets('App 能够正常构建和加载', (WidgetTester tester) async {
    // 构建 App 并触发第一帧
    await tester.pumpWidget(const MiniArmApp());
    // 检查 App 至少渲染出了某个 Widget
    expect(find.byType(MiniArmApp), findsOneWidget);
  });
}

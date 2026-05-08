import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_maestro/main.dart';

void main() {
  testWidgets('Video Maestro app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const VideoMaestroApp());

    // Verify that the app loads
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

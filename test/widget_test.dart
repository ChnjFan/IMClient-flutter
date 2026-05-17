import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:im_client/app.dart';

void main() {
  testWidgets('App should render login page', (WidgetTester tester) async {
    await tester.pumpWidget(const IMClientApp());
    expect(find.text('IM Client'), findsWidgets);
    expect(find.text('登录'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });
}

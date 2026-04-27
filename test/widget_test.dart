// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tarbie_hub/data/app_database.dart';
import 'package:tarbie_hub/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await AppDatabase.instance.close();
    await AppDatabase.instance.init(inMemory: true);
  });

  testWidgets('Login screen renders for desktop MVP', (WidgetTester tester) async {
    await tester.pumpWidget(const TarbieHubApp());

    expect(find.text('College Tarbie Hub'), findsOneWidget);
    expect(find.text('Войти'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });
}

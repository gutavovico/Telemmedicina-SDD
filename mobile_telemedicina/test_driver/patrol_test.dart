// ignore_for_file: undefined_function, avoid_print

import 'package:patrol/patrol.dart';

Future<void> main() async {
  await patrol(
    // Optional: configure Patrol behavior
    nativeAutomation: true,
    // Optional: custom setup
    onNativeError: (error, stackTrace) {
      print('Native error: $error');
      print(stackTrace);
    },
  );
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scariCANO/app.dart';

void main() {
  runApp(
    const ProviderScope(
      child: ScariCANOApp(),
    ),
  );
}

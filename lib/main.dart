import 'package:flutter/material.dart';
import 'app.dart';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  print(dotenv.env);
  runApp(const MyApp());
}
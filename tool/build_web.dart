#!/usr/bin/env dart
// Build script: processes web/index.html.template with env vars
// Usage: dart run tool/build_web.dart

import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  // Load .env
  await dotenv.load(fileName: '.env');

  // Read template
  final templateFile = File('web/index.html.template');
  if (!await templateFile.exists()) {
    stderr.writeln('❌ Template not found: web/index.html.template');
    exit(1);
  }

  String template = await templateFile.readAsString();

  // Replace placeholders
  final replacements = {
    '{{FIREBASE_API_KEY}}': dotenv.env['FIREBASE_API_KEY'] ?? '',
    '{{FIREBASE_AUTH_DOMAIN}}': dotenv.env['FIREBASE_AUTH_DOMAIN'] ?? '',
    '{{FIREBASE_PROJECT_ID}}': dotenv.env['FIREBASE_PROJECT_ID'] ?? '',
    '{{FIREBASE_STORAGE_BUCKET}}': dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? '',
    '{{FIREBASE_MESSAGING_SENDER_ID}}': dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '',
    '{{FIREBASE_APP_ID}}': dotenv.env['FIREBASE_APP_ID'] ?? '',
  };

  // Check for missing values
  final missing = replacements.entries.where((e) => e.value.isEmpty).toList();
  if (missing.isNotEmpty) {
    stderr.writeln('❌ Missing env vars: ${missing.map((e) => e.key).join(', ')}');
    exit(1);
  }

  String output = template;
  for (final entry in replacements.entries) {
    output = output.replaceAll(entry.key, entry.value);
  }

  // Write final index.html
  final outputFile = File('web/index.html');
  await outputFile.writeAsString(output);

  stdout.writeln('✅ Generated web/index.html from template');
}
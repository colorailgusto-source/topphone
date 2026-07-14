#!/usr/bin/env dart
// Tool per generare web/index.html da template con variabili d'ambiente
// Uso: dart run tool/generate_web_index.dart

import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  await dotenv.load(fileName: '.env');

  final templateFile = File('web/index.html.template');
  final outputFile = File('web/index.html');

  if (!await templateFile.exists()) {
    stderr.writeln('❌ Template non trovato: web/index.html.template');
    exit(1);
  }

  String template = await templateFile.readAsString();

  // Sostituisci placeholder con valori da .env
  final replacements = {
    '{{FIREBASE_API_KEY}}': dotenv.env['FIREBASE_API_KEY'] ?? '',
    '{{FIREBASE_AUTH_DOMAIN}}': dotenv.env['FIREBASE_AUTH_DOMAIN'] ?? '',
    '{{FIREBASE_PROJECT_ID}}': dotenv.env['FIREBASE_PROJECT_ID'] ?? '',
    '{{FIREBASE_STORAGE_BUCKET}}': dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? '',
    '{{FIREBASE_MESSAGING_SENDER_ID}}': dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '',
    '{{FIREBASE_APP_ID}}': dotenv.env['FIREBASE_APP_ID'] ?? '',
  };

  for (final entry in replacements.entries) {
    if (entry.value.isEmpty) {
      stderr.writeln('⚠️ Variabile mancante: ${entry.key}');
    }
    template = template.replaceAll(entry.key, entry.value);
  }

  await outputFile.writeAsString(template);
  stdout.writeln('✅ Generato web/index.html con variabili iniettate');
}
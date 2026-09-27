import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

class Option {
  const Option(this.id, this.label, [this.icon]);
  final String id;
  final String label;
  final IconData? icon;
}

/// Flow choices in the order shown in the Log Today sheet.
const flowOptions = [
  Option('none', 'None'),
  Option('spotting', 'Spotting'),
  Option('light', 'Light'),
  Option('medium', 'Medium'),
  Option('heavy', 'Heavy'),
];

const symptomOptions = [
  Option('cramps', 'Cramps'),
  Option('headache', 'Headache'),
  Option('bloating', 'Bloating'),
  Option('fatigue', 'Fatigue'),
  Option('back_pain', 'Back pain'),
  Option('acne', 'Acne'),
  Option('nausea', 'Nausea'),
];

const moodOptions = [
  Option('good', 'Good', Symbols.sentiment_satisfied),
  Option('okay', 'Okay', Symbols.sentiment_neutral),
  Option('low', 'Low', Symbols.sentiment_dissatisfied),
  Option('irritated', 'Irritated', Symbols.mood_bad),
  Option('anxious', 'Anxious', Symbols.cyclone),
  Option('energetic', 'Energetic', Symbols.bolt),
];

/// Label for a stored id; custom symptoms ("Add other") are stored as their label.
String labelFor(List<Option> options, String id) {
  for (final o in options) {
    if (o.id == id) return o.label;
  }
  return id;
}

const minCycleLength = 21;
const maxCycleLength = 45;
const minPeriodLength = 2;
const maxPeriodLength = 10;

/// Cycle day beyond which a cycle is flagged irregular.
const irregularCycleDay = 45;

const appVersion = '1.0.0';

/// Base URL of the chat server (the NutriCook backend deployed on Render).
///
/// Point at a local server at build time instead:
///   flutter run --dart-define=SECRET_CHAT_URL=http://127.0.0.1:8010
/// (the Android emulator reaches the host machine at http://10.0.2.2:8010).
String get secretChatBaseUrl {
  const override = String.fromEnvironment('SECRET_CHAT_URL');
  return override.isNotEmpty ? override : 'https://secret-chat-fyob.onrender.com';
}

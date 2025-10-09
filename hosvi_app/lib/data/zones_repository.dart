// lib/data/zones_repository.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../domain/zones.dart';

class ZonesRepository {
  static const _assetPath = 'assets/data/zones.json';

  Future<List<Zone>> loadZones() async {
    final raw = await rootBundle.loadString(_assetPath);
    final List<dynamic> data = json.decode(raw);
    return data.map((e) => Zone.fromJson(e as Map<String, dynamic>)).toList();
  }
}

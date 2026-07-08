import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/location_result.dart';
import '../models/suburb_entry.dart';

/// In-memory prefix index of Australian suburbs bundled with the app.
class SuburbIndex {
  SuburbIndex._();

  static final SuburbIndex instance = SuburbIndex._();

  static const _assetPath = 'assets/data/australian_suburbs.json';

  List<SuburbEntry> _entries = const [];
  List<String> _sortKeys = const [];
  bool _loaded = false;

  bool get isLoaded => _loaded;

  int get length => _entries.length;

  Future<void> load() async {
    if (_loaded) return;

    final raw = await rootBundle.loadString(_assetPath);
    final decoded = (jsonDecode(raw) as List<dynamic>)
        .map((item) => SuburbEntry.fromJson(item as Map<String, dynamic>))
        .toList();

    final indexed = List.generate(
      decoded.length,
      (index) => (entry: decoded[index], key: decoded[index].name.toLowerCase()),
    )..sort((a, b) {
        final byName = a.key.compareTo(b.key);
        if (byName != 0) return byName;
        return a.entry.state.compareTo(b.entry.state);
      });

    _entries = [for (final item in indexed) item.entry];
    _sortKeys = [for (final item in indexed) item.key];
    _loaded = true;
  }

  /// Prefix search on suburb name or postcode. Returns at most [limit] matches.
  List<SuburbEntry> search(String query, {int limit = 8}) {
    _ensureLoaded();

    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];

    final normalized = trimmed.toLowerCase();
    final digitsOnly = RegExp(r'^\d+$').hasMatch(trimmed);

    if (digitsOnly) {
      return _searchPostcode(trimmed, limit: limit);
    }

    return _searchNamePrefix(normalized, limit: limit);
  }

  List<LocationResult> searchAsLocationResults(String query, {int limit = 8}) {
    return search(query, limit: limit).map(_toLocationResult).toList();
  }

  SuburbEntry? findExact(String name, String? state) {
    _ensureLoaded();
    final normalizedName = name.trim().toLowerCase();
    final normalizedState = state?.trim().toUpperCase();

    for (var index = 0; index < _entries.length; index++) {
      final entry = _entries[index];
      if (_sortKeys[index] != normalizedName) continue;
      if (normalizedState == null || entry.state == normalizedState) {
        return entry;
      }
    }
    return null;
  }

  List<SuburbEntry> _searchNamePrefix(String normalized, {required int limit}) {
    final start = _lowerBound(normalized);
    final matches = <SuburbEntry>[];

    for (var index = start; index < _entries.length; index++) {
      final key = _sortKeys[index];
      if (!key.startsWith(normalized)) break;
      matches.add(_entries[index]);
      if (matches.length >= limit) break;
    }

    return matches;
  }

  List<SuburbEntry> _searchPostcode(String postcode, {required int limit}) {
    final matches = <SuburbEntry>[];
    for (final entry in _entries) {
      final entryPostcode = entry.postcode;
      if (entryPostcode != null && entryPostcode.startsWith(postcode)) {
        matches.add(entry);
        if (matches.length >= limit) break;
      }
    }
    return matches;
  }

  int _lowerBound(String prefix) {
    var low = 0;
    var high = _sortKeys.length;
    while (low < high) {
      final mid = low + ((high - low) >> 1);
      if (_sortKeys[mid].compareTo(prefix) < 0) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  LocationResult _toLocationResult(SuburbEntry entry) {
    final subtitleParts = [
      ?entry.postcode,
      entry.state,
    ];
    return LocationResult(
      title: entry.name,
      subtitle: subtitleParts.join(' · '),
      latitude: entry.latitude ?? 0,
      longitude: entry.longitude ?? 0,
      state: entry.state,
      isSuburbLike: true,
      needsGeocode: !entry.hasCoordinates,
    );
  }

  void _ensureLoaded() {
    if (!_loaded) {
      throw StateError('SuburbIndex.load() must complete before searching');
    }
  }

  /// Visible for tests that inject entries without loading the asset bundle.
  void debugReplaceEntries(List<SuburbEntry> entries) {
    final indexed = List.generate(
      entries.length,
      (index) => (entry: entries[index], key: entries[index].name.toLowerCase()),
    )..sort((a, b) {
        final byName = a.key.compareTo(b.key);
        if (byName != 0) return byName;
        return a.entry.state.compareTo(b.entry.state);
      });

    _entries = [for (final item in indexed) item.entry];
    _sortKeys = [for (final item in indexed) item.key];
    _loaded = true;
  }
}

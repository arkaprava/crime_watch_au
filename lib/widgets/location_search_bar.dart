import 'dart:async';

import 'package:flutter/material.dart';

import '../models/location_result.dart';
import '../services/location_search_service.dart';
import '../theme/app_theme.dart';
import 'surface_card.dart';

typedef LocationSelectedCallback = void Function(LocationResult location);

/// Search bar for Australian suburbs and postcodes with debounced suggestions.
class LocationSearchBar extends StatefulWidget {
  const LocationSearchBar({super.key, required this.onLocationSelected});

  final LocationSelectedCallback onLocationSelected;

  @override
  State<LocationSearchBar> createState() => _LocationSearchBarState();
}

class _LocationSearchBarState extends State<LocationSearchBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _service = LocationSearchService();

  Timer? _debounce;
  List<LocationResult> _results = const [];
  bool _isSearching = false;
  String? _error;
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    setState(() => _showResults = _focusNode.hasFocus && _results.isNotEmpty);
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _results = const [];
        _error = null;
        _isSearching = false;
        _showResults = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () => _search(value));
  }

  Future<void> _search(String query) async {
    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final results = await _service.search(query);
      if (!mounted || _controller.text.trim() != query.trim()) return;
      setState(() {
        _results = results;
        _isSearching = false;
        _showResults = _focusNode.hasFocus && results.isNotEmpty;
      });
    } on LocationSearchException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _results = const [];
        _isSearching = false;
        _showResults = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not search locations';
        _results = const [];
        _isSearching = false;
        _showResults = false;
      });
    }
  }

  void _select(LocationResult location) {
    _controller.text = location.title;
    _focusNode.unfocus();
    setState(() {
      _showResults = false;
      _results = const [];
    });
    widget.onLocationSelected(location);
  }

  void _clear() {
    _controller.clear();
    setState(() {
      _results = const [];
      _error = null;
      _showResults = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              const SizedBox(width: 8),
              Icon(Icons.search, color: AppTheme.slate.withValues(alpha: 0.7)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  onChanged: _onQueryChanged,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (value) {
                    if (_results.isNotEmpty) _select(_results.first);
                  },
                  decoration: const InputDecoration(
                    hintText: 'Search suburb or postcode',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 0, vertical: 12),
                  ),
                ),
              ),
              if (_isSearching)
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (_controller.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: _clear,
                  tooltip: 'Clear search',
                ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        if (_showResults)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SurfaceCard(
              padding: EdgeInsets.zero,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _results.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final result = _results[index];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor:
                          AppTheme.amber.withValues(alpha: 0.15),
                      child: const Icon(Icons.place, size: 18, color: AppTheme.navy),
                    ),
                    title: Text(
                      result.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(result.subtitle),
                    onTap: () => _select(result),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

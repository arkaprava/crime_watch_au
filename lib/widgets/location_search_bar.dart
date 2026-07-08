import 'package:flutter/material.dart';

import '../models/location_result.dart';
import '../services/location_search_service.dart';
import '../theme/app_theme.dart';
import 'surface_card.dart';

typedef LocationSelectedCallback = void Function(LocationResult location);

/// Search bar for Australian suburbs and postcodes with local autocomplete.
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

  bool _isResolving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<Iterable<LocationResult>> _fetchOptions(TextEditingValue value) async {
    final trimmed = value.text.trim();
    if (trimmed.length < 2) {
      if (_error != null) {
        setState(() => _error = null);
      }
      return const [];
    }

    return _service.search(trimmed);
  }

  Future<void> _handleSelection(LocationResult option) async {
    setState(() {
      _isResolving = option.needsGeocode;
      _error = null;
    });

    try {
      final resolved = await _service.resolveSelection(option);
      if (!mounted) return;
      setState(() => _isResolving = false);
      widget.onLocationSelected(resolved);
    } on LocationSearchException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _isResolving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not resolve suburb location';
        _isResolving = false;
      });
    }
  }

  void _clear() {
    _controller.clear();
    setState(() {
      _isResolving = false;
      _error = null;
    });
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RawAutocomplete<LocationResult>(
          textEditingController: _controller,
          focusNode: _focusNode,
          displayStringForOption: (option) => option.title,
          optionsBuilder: _fetchOptions,
          onSelected: _handleSelection,
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return SurfaceCard(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Icon(Icons.search,
                      color: AppTheme.slate.withValues(alpha: 0.7)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      textInputAction: TextInputAction.search,
                      autocorrect: false,
                      enableSuggestions: false,
                      onSubmitted: (_) => onFieldSubmitted(),
                      decoration: const InputDecoration(
                        hintText: 'Search suburb or postcode',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  if (_isResolving)
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: controller,
                      builder: (context, value, _) {
                        if (value.text.isEmpty) {
                          return const SizedBox(width: 8);
                        }
                        return IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: _clear,
                          tooltip: 'Clear search',
                        );
                      },
                    ),
                ],
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            final items = options.toList();
            if (items.isEmpty) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SurfaceCard(
                padding: EdgeInsets.zero,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final result = items[index];
                      return Material(
                        color: Colors.transparent,
                        child: ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor:
                                AppTheme.amber.withValues(alpha: 0.15),
                            child: const Icon(Icons.place,
                                size: 18, color: AppTheme.navy),
                          ),
                          title: Text(
                            result.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(result.subtitle),
                          onTap: () => onSelected(result),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
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
      ],
    );
  }
}

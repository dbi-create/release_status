import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:release_status/models/platform_origin.dart';
import 'package:release_status/models/platform_status.dart';
import 'package:release_status/models/release_title.dart';
import 'package:release_status/monitoring/apply_monitoring_result.dart';
import 'package:release_status/monitoring/availability_monitor.dart';
import 'package:release_status/monitoring/discovered_listings.dart';
import 'package:release_status/monitoring/discovery_monitor.dart';
import 'package:release_status/monitoring/listing_url_verifier.dart';
import 'package:release_status/monitoring/title_identity.dart';
import 'package:release_status/monitoring/title_lookup.dart';
import 'package:release_status/state/listing_url_scope.dart';
import 'package:release_status/state/title_catalog.dart';
import 'package:release_status/widgets/platform_status_row.dart';

const int _minimumReleaseYear = 1888;
const String _noListingsFoundMessage =
    'No listings were found on any platforms for this title.';

class TitleFormScreen extends StatefulWidget {
  const TitleFormScreen({super.key, this.existingTitle});

  final ReleaseTitle? existingTitle;

  bool get isEditing => existingTitle != null;

  @override
  State<TitleFormScreen> createState() => _TitleFormScreenState();
}

class _TitleFormScreenState extends State<TitleFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _yearController;
  late final TextEditingController _imdbController;
  late final TextEditingController _tmdbController;
  late final TextEditingController _directorController;
  late final TextEditingController _producerController;
  late final TextEditingController _writerController;

  late List<PlatformStatus> _platforms;
  late Set<String> _originalPlatformKeys;

  String? _contentType;
  String? _contentTypeError;
  String? _platformsError;
  bool _submitted = false;
  bool _isSaving = false;
  bool _lookingUp = false;
  bool _autoPopulating = false;
  String? _lookupMessage;
  String? _autoPopulateMessage;
  String? _posterUrl;
  List<TitleLookupMatch> _matches = const [];
  TitleLookupMatch? _selectedMatch;
  late bool _additionalExpanded;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingTitle;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _yearController = TextEditingController(
      text: existing == null ? '' : '${existing.releaseYear}',
    );
    _imdbController = TextEditingController(text: existing?.imdbId ?? '');
    _tmdbController = TextEditingController(text: existing?.tmdbId ?? '');
    _directorController = TextEditingController(text: existing?.director ?? '');
    _producerController = TextEditingController(text: existing?.producer ?? '');
    _writerController = TextEditingController(text: existing?.writer ?? '');
    _contentType = existing?.contentType;
    _platforms = List<PlatformStatus>.from(existing?.platforms ?? const []);
    _posterUrl = existing?.posterUrl;
    _originalPlatformKeys = {
      for (final platform in existing?.platforms ?? const <PlatformStatus>[])
        _platformKey(platform.platformName),
    };
    _additionalExpanded = false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _yearController.dispose();
    _imdbController.dispose();
    _tmdbController.dispose();
    _directorController.dispose();
    _producerController.dispose();
    _writerController.dispose();
    super.dispose();
  }

  int get _maximumReleaseYear => DateTime.now().year + 5;

  bool get _showLicensedPlatforms =>
      widget.isEditing || _selectedMatch != null;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isCompact = MediaQuery.sizeOf(context).width < 720;
    final fieldTextStyle = textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final fieldLabelStyle = fieldTextStyle?.copyWith(
      color: colorScheme.onSurface,
      fontWeight: FontWeight.w600,
    );
    final floatingLabelStyle = fieldTextStyle?.copyWith(
      color: colorScheme.onSurface,
      fontWeight: FontWeight.w700,
      fontSize: 12,
      height: 1,
    );
    const fieldHeight = 56.0;
    const additionalFieldHeight = fieldHeight * 0.8;
    final additionalTextStyle = textTheme.bodyLarge?.copyWith(
      fontSize: (textTheme.bodyLarge?.fontSize ?? 16) * 0.8,
    );
    final additionalLabelStyle = additionalTextStyle?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    final additionalDecoration = InputDecoration(
      isDense: true,
      labelStyle: additionalLabelStyle,
      floatingLabelStyle: additionalLabelStyle,
      hintStyle: additionalLabelStyle,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
    final fieldDecoration = InputDecoration(
      isDense: true,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: fieldLabelStyle,
      floatingLabelStyle: floatingLabelStyle,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    );

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Title' : 'Add Title'),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: _submitted
            ? AutovalidateMode.always
            : AutovalidateMode.disabled,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            isCompact ? 20 : 32,
            12,
            isCompact ? 20 : 32,
            isCompact ? 96 : 40,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.isEditing) ...[
                  Text(
                    'Update the title you own, produce, distribute, or control.',
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 65,
                      child: SizedBox(
                        height: fieldHeight,
                        child: TextFormField(
                          key: const ValueKey<String>('title-name-field'),
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          style: fieldTextStyle,
                          decoration: fieldDecoration.copyWith(
                            labelText: 'Title name',
                            hintText: 'Title',
                          ),
                          validator: _validateName,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 35,
                      child: SizedBox(
                        height: fieldHeight,
                        child: TextFormField(
                          key: const ValueKey<String>('release-year-field'),
                          controller: _yearController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          style: fieldTextStyle,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          decoration: fieldDecoration.copyWith(
                            labelText: 'Release year',
                          ),
                          validator: _validateYear,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 65,
                      child: SizedBox(
                        height: fieldHeight,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            key: const ValueKey<String>(
                              'advanced-identity-tile',
                            ),
                            onTap: () {
                              setState(() {
                                _additionalExpanded = !_additionalExpanded;
                              });
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: InputDecorator(
                              decoration: fieldDecoration.copyWith(
                                labelText: 'Additional information',
                              ),
                              isEmpty: true,
                              child: Row(
                                children: [
                                  const Expanded(child: SizedBox.shrink()),
                                  Icon(
                                    _additionalExpanded
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    size: 22,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 35,
                      child: SizedBox(
                        height: fieldHeight,
                        child: Builder(
                          builder: (menuContext) {
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                key: const ValueKey<String>(
                                  'content-type-field',
                                ),
                                onTap: () async {
                                  final box =
                                      menuContext.findRenderObject() as RenderBox;
                                  final overlay =
                                      Navigator.of(menuContext)
                                          .overlay!
                                          .context
                                          .findRenderObject()!
                                          as RenderBox;
                                  final selected = await showMenu<String>(
                                    context: menuContext,
                                    position: RelativeRect.fromRect(
                                      Rect.fromPoints(
                                        box.localToGlobal(
                                          Offset.zero,
                                          ancestor: overlay,
                                        ),
                                        box.localToGlobal(
                                          box.size.bottomRight(Offset.zero),
                                          ancestor: overlay,
                                        ),
                                      ),
                                      Offset.zero & overlay.size,
                                    ),
                                    items: const [
                                      PopupMenuItem<String>(
                                        key: ValueKey<String>(
                                          'content-type-Movie',
                                        ),
                                        value: 'Movie',
                                        child: Text('Movie'),
                                      ),
                                      PopupMenuItem<String>(
                                        key: ValueKey<String>(
                                          'content-type-TV Series',
                                        ),
                                        value: 'TV Series',
                                        child: Text('TV Series'),
                                      ),
                                    ],
                                  );
                                  if (selected == null) {
                                    return;
                                  }
                                  setState(() {
                                    _contentType = selected;
                                    _contentTypeError = null;
                                  });
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: InputDecorator(
                                  decoration: fieldDecoration.copyWith(
                                    labelText: 'Type',
                                  ),
                                  isEmpty: _contentType == null,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _contentType == null
                                            ? const SizedBox.shrink()
                                            : Text(
                                                _contentType!,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: fieldTextStyle,
                                              ),
                                      ),
                                      Icon(
                                        Icons.expand_more,
                                        size: 22,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                if (_additionalExpanded) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: additionalFieldHeight,
                    child: TextFormField(
                      key: const ValueKey<String>('tmdb-id-field'),
                      controller: _tmdbController,
                      textInputAction: TextInputAction.next,
                      style: additionalTextStyle,
                      decoration: additionalDecoration.copyWith(
                        labelText: 'TMDb ID',
                        hintText: 'Optional',
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: additionalFieldHeight,
                    child: TextFormField(
                      key: const ValueKey<String>('imdb-id-field'),
                      controller: _imdbController,
                      textInputAction: TextInputAction.next,
                      style: additionalTextStyle,
                      decoration: additionalDecoration.copyWith(
                        labelText: 'IMDb ID',
                        hintText: 'Optional, such as tt4574334',
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: additionalFieldHeight,
                    child: TextFormField(
                      key: const ValueKey<String>('director-field'),
                      controller: _directorController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      style: additionalTextStyle,
                      decoration: additionalDecoration.copyWith(
                        labelText: 'Director',
                        hintText: 'Optional',
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: additionalFieldHeight,
                    child: TextFormField(
                      key: const ValueKey<String>('producer-field'),
                      controller: _producerController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      style: additionalTextStyle,
                      decoration: additionalDecoration.copyWith(
                        labelText: 'Producer',
                        hintText: 'Optional',
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: additionalFieldHeight,
                    child: TextFormField(
                      key: const ValueKey<String>('writer-field'),
                      controller: _writerController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      style: additionalTextStyle,
                      decoration: additionalDecoration.copyWith(
                        labelText: 'Writer',
                        hintText: 'Optional',
                      ),
                    ),
                  ),
                ],
                if (_contentTypeError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _contentTypeError!,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                _GradientActionButton(
                  buttonKey: const ValueKey<String>(
                    'find-title-matches-button',
                  ),
                  label: _lookingUp || _autoPopulating
                      ? 'SEARCHING…'
                      : 'SEARCH',
                  textStyle: fieldTextStyle,
                  onTap: _lookingUp || _autoPopulating || _isSaving
                      ? null
                      : _findMatches,
                ),
                if (_lookupMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _lookupMessage!,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (_matches.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 80,
                        child: SizedBox(
                          height: fieldHeight,
                          child: DropdownButtonFormField<TitleLookupMatch>(
                            key: const ValueKey<String>('title-match-dropdown'),
                            initialValue: _selectedMatch,
                            isExpanded: true,
                            style: fieldTextStyle,
                            decoration: fieldDecoration.copyWith(
                              labelText: 'Select Correct Title',
                            ),
                            items: [
                              for (final match in _matches)
                                DropdownMenuItem<TitleLookupMatch>(
                                  value: match,
                                  child: Text(
                                    match.label,
                                    overflow: TextOverflow.ellipsis,
                                    style: fieldTextStyle,
                                  ),
                                ),
                            ],
                            onChanged: _applyMatch,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 20,
                        child: _buildSaveTitleButton(
                          fieldTextStyle,
                          stacked: true,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  _buildSaveTitleButton(fieldTextStyle),
                ],
                if (_showLicensedPlatforms) ...[
                const SizedBox(height: 24),
                const Divider(height: 1),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Licensed Platforms',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      key: const ValueKey<String>('add-manual-channel-button'),
                      onPressed: _isSaving ? null : _openManualChannelDialog,
                      child: const Text('+ Manual Channel'),
                    ),
                  ],
                ),
                if (_autoPopulateMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _autoPopulateMessage!,
                    key: const ValueKey<String>('auto-populate-message'),
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: textTheme.bodyMedium?.copyWith(
                      color: _autoPopulateMessage == _noListingsFoundMessage
                          ? StatusVisuals.waiting.color
                          : colorScheme.onSurfaceVariant,
                      fontWeight: _autoPopulateMessage == _noListingsFoundMessage
                          ? FontWeight.w700
                          : FontWeight.w400,
                      fontSize:
                          (textTheme.bodyMedium?.fontSize ?? 14) -
                          (_autoPopulateMessage == _noListingsFoundMessage
                              ? 1
                              : 0),
                    ),
                  ),
                ],
                if (_platformsError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _platformsError!,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                for (var i = 0; i < _platforms.length; i++) ...[
                  _PlatformDraftTile(
                    platform: _platforms[i],
                    onRemove: () => _removePlatform(i),
                    onRemoveLiveStatus: _platforms[i].canRemoveUserConfirmedLive
                        ? () => _removeLiveStatus(i)
                        : null,
                  ),
                  const SizedBox(height: 8),
                ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSaveTitleButton(TextStyle? textStyle, {bool stacked = false}) {
    return _GradientActionButton(
      buttonKey: const ValueKey<String>('save-title-button'),
      label: _isSaving
          ? 'SAVING…'
          : (stacked ? 'SAVE\nTITLE' : 'SAVE TITLE'),
      textStyle: textStyle,
      maxLines: stacked ? 2 : 1,
      colors: const [Color(0xFF2E5A86), Color(0xFF4A7FB5)],
      onTap: _isSaving || _lookingUp || _autoPopulating ? null : _save,
    );
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter a title name.';
    }
    return null;
  }

  String? _validateYear(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Enter a four-digit release year.';
    }
    if (trimmed.length != 4) {
      return 'Enter a four-digit year, such as 2024.';
    }
    final year = int.tryParse(trimmed);
    if (year == null) {
      return 'Enter a four-digit year, such as 2024.';
    }
    if (year < _minimumReleaseYear || year > _maximumReleaseYear) {
      return 'Enter a year between $_minimumReleaseYear and $_maximumReleaseYear.';
    }
    return null;
  }

  Future<void> _openManualChannelDialog() async {
    final added = await showDialog<PlatformStatus>(
      context: context,
      builder: (dialogContext) {
        return _ManualChannelDialog(
          titleName: _nameController.text.trim(),
          existingKeys: {
            for (final platform in _platforms) _platformKey(platform.platformName),
          },
        );
      },
    );
    if (!mounted || added == null) {
      return;
    }
    setState(() {
      _platformsError = null;
      _platforms = [..._platforms, added];
    });
  }

  Future<void> _removePlatform(int index) async {
    final platform = _platforms[index];
    final isExisting = _originalPlatformKeys.contains(
      _platformKey(platform.platformName),
    );
    if (isExisting) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Remove ${platform.platformName}?'),
            content: Text(
              'Remove this licensed platform from ${widget.existingTitle?.name ?? 'this title'}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Remove'),
              ),
            ],
          );
        },
      );
      if (confirmed != true || !mounted) {
        return;
      }
    }
    setState(() {
      _platforms = [
        for (var i = 0; i < _platforms.length; i++)
          if (i != index) _platforms[i],
      ];
      if (_platforms.isNotEmpty) {
        _platformsError = null;
      }
    });
  }

  Future<void> _removeLiveStatus(int index) async {
    final platform = _platforms[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Remove live status from ${platform.platformName}?'),
          content: const Text(
            'This goes back to not live. Use this if the confirmation was wrong or the title is no longer there.',
          ),
          actions: [
            TextButton(
              key: const ValueKey<String>('cancel-remove-live-status-button'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey<String>('confirm-remove-live-status-button'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Remove Live Status'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _platforms = [
        for (var i = 0; i < _platforms.length; i++)
          if (i == index)
            applyClearUserConfirmedLive(
              _platforms[i],
              clearedAt: DateTime.now(),
            )
          else
            _platforms[i],
      ];
    });
  }

  void _save() {
    if (_isSaving) {
      return;
    }
    setState(() {
      _isSaving = true;
      _submitted = true;
    });

    final formValid = _formKey.currentState?.validate() ?? false;
    final contentType = _contentType;
    final contentTypeError = contentType == null
        ? 'Select Movie or TV Series.'
        : null;

    if (!formValid || contentTypeError != null) {
      setState(() {
        _isSaving = false;
        _contentTypeError = contentTypeError;
        _platformsError = null;
      });
      return;
    }

    final name = _nameController.text.trim();
    final year = int.parse(_yearController.text.trim());
    final catalog = TitleCatalogScope.of(context);
    final existing = widget.existingTitle;

    if (existing == null) {
      catalog.addTitle(
        name: name,
        contentType: contentType!,
        releaseYear: year,
        platformNames: [
          for (final platform in _platforms) platform.platformName,
        ],
        platforms: List<PlatformStatus>.from(_platforms),
        imdbId: _imdbController.text,
        tmdbId: _tmdbController.text,
        director: _directorController.text,
        producer: _producerController.text,
        writer: _writerController.text,
        posterUrl: _posterUrl,
        lastLookedUpAt: _selectedMatch != null ? DateTime.now() : null,
      );
    } else {
      catalog.updateTitle(
        existing.copyWith(
          name: name,
          contentType: contentType,
          releaseYear: year,
          platforms: List<PlatformStatus>.from(_platforms),
          imdbId: _imdbController.text.trim(),
          tmdbId: _tmdbController.text.trim(),
          director: _directorController.text.trim(),
          producer: _producerController.text.trim(),
          writer: _writerController.text.trim(),
          posterUrl: _posterUrl ?? existing.posterUrl,
          lastLookedUpAt: _selectedMatch != null
              ? DateTime.now()
              : existing.lastLookedUpAt,
        ),
      );
    }

    Navigator.of(context).pop();
  }

  Future<void> _loadTmdbChannels() async {
    final name = _nameController.text.trim();
    final contentType = _contentType;
    final yearText = _yearController.text.trim();
    final year = int.tryParse(yearText);
    if (name.isEmpty ||
        contentType == null ||
        year == null ||
        yearText.length != 4) {
      setState(() {
        _autoPopulateMessage =
            'Pick the exact matching title first, or enter the name, type, and year.';
      });
      return;
    }

    final monitor = AvailabilityMonitorScope.of(context);
    if (monitor is! DiscoveryMonitor || !monitor.isConfigured) {
      setState(() {
        _autoPopulateMessage =
            'TMDb channels are not available. Add a channel TMDb does not list with a live URL.';
      });
      return;
    }

    setState(() {
      _autoPopulating = true;
      _autoPopulateMessage = null;
    });

    final discoveryMonitor = monitor as DiscoveryMonitor;
    try {
      final discovery = await discoveryMonitor.discover(
        title: TitleIdentity(
          title: name,
          contentType: contentType,
          releaseYear: year,
          imdbId: _imdbController.text.trim(),
          tmdbId: _tmdbController.text.trim(),
          director: _directorController.text.trim(),
          producer: _producerController.text.trim(),
          writer: _writerController.text.trim(),
        ),
      );
      if (!mounted) {
        return;
      }
      if (discovery.failed || !discovery.isVerified) {
        setState(() {
          _autoPopulating = false;
          _autoPopulateMessage =
              discovery.detail ??
              'Could not identify this title well enough to add channels.';
        });
        return;
      }
      final merged = applyDiscoveredPlatforms(
        current: _platforms,
        listings: discovery.platforms,
      );
      setState(() {
        _autoPopulating = false;
        _platforms = merged;
        _platformsError = null;
        if (discovery.matchedTmdbId != null &&
            discovery.matchedTmdbId!.trim().isNotEmpty) {
          _tmdbController.text = discovery.matchedTmdbId!;
        }
        _posterUrl = discovery.posterUrl ?? _posterUrl;
        if (discovery.platforms.isEmpty) {
          _autoPopulateMessage = _noListingsFoundMessage;
        } else {
          final foundCount = discovery.platforms.length;
          _autoPopulateMessage =
              'Found $foundCount Channel${foundCount == 1 ? '' : 's'}.';
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _autoPopulating = false;
        _autoPopulateMessage =
            'Could not look up TMDb channels. Add a channel it does not list with a live URL.';
      });
    }
  }

  Future<void> _findMatches() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _lookupMessage = 'Enter a title name first.';
        _matches = const [];
        _selectedMatch = null;
      });
      return;
    }
    final monitor = AvailabilityMonitorScope.of(context);
    if (monitor is! TitleLookup || !monitor.isConfigured) {
      setState(() {
        _lookupMessage =
            'Title lookup is not configured. Enter the type and year yourself.';
        _matches = const [];
        _selectedMatch = null;
      });
      return;
    }
    setState(() {
      _lookingUp = true;
      _lookupMessage = null;
      _selectedMatch = null;
    });
    final lookup = monitor as TitleLookup;
    try {
      final matches = await lookup.searchByName(
        name: name,
        contentType: _contentType,
        year: int.tryParse(_yearController.text.trim()),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _lookingUp = false;
        _matches = matches;
        _selectedMatch = null;
        _lookupMessage = matches.isEmpty
            ? 'No matching titles were found. Select Movie or TV Series, paste the TMDb page URL, or enter the type and year yourself.'
            : 'Select the correct title.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _lookingUp = false;
        _matches = const [];
        _selectedMatch = null;
        _lookupMessage =
            'Could not look up titles. Enter the type and year yourself.';
      });
    }
  }

  void _applyMatch(TitleLookupMatch? match) {
    if (match == null) {
      return;
    }
    setState(() {
      _selectedMatch = match;
      _fillFromMatch(match);
    });
    _loadTmdbChannels();
  }

  void _fillFromMatch(TitleLookupMatch match) {
    _nameController.text = match.name;
    _contentType = match.contentType;
    _contentTypeError = null;
    _yearController.text = match.year == null ? '' : '${match.year}';
    if (match.tmdbId != null) {
      _tmdbController.text = match.tmdbId!;
    }
    _posterUrl = match.posterUrl ?? _posterUrl;
  }
}

class _GradientActionButton extends StatelessWidget {
  const _GradientActionButton({
    required this.buttonKey,
    required this.label,
    required this.textStyle,
    required this.onTap,
    this.maxLines = 1,
    this.colors,
  });

  final Key buttonKey;
  final String label;
  final TextStyle? textStyle;
  final VoidCallback? onTap;
  final int maxLines;
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final buttonTextStyle = textStyle?.copyWith(
      color: Colors.white,
      fontSize: (textStyle?.fontSize ?? 14) + (maxLines > 1 ? 0 : 3),
      fontWeight: FontWeight.w700,
      letterSpacing: maxLines > 1 ? 0.2 : 0.8,
      height: maxLines > 1 ? 1.05 : null,
    );
    return SizedBox(
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white, width: 1.4),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors:
                colors ??
                [
                  Color.lerp(colorScheme.primary, Colors.black, 0.22)!,
                  colorScheme.primary,
                ],
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: buttonKey,
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: maxLines > 1
                    ? Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: maxLines,
                        style: buttonTextStyle,
                      )
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          maxLines: 1,
                          style: buttonTextStyle,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ManualChannelDialog extends StatefulWidget {
  const _ManualChannelDialog({
    required this.titleName,
    required this.existingKeys,
  });

  final String titleName;
  final Set<String> existingKeys;

  @override
  State<_ManualChannelDialog> createState() => _ManualChannelDialogState();
}

class _ManualChannelDialogState extends State<_ManualChannelDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  String? _errorText;
  bool _adding = false;

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_adding) {
      return;
    }
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _errorText = 'Enter the channel name.';
      });
      return;
    }
    if (widget.existingKeys.contains(_platformKey(name))) {
      setState(() {
        _errorText = 'That platform is already listed for this title.';
      });
      return;
    }
    if (widget.titleName.isEmpty) {
      setState(() {
        _errorText =
            'Enter the title name first so the listing page can be checked.';
      });
      return;
    }
    if (parseListingUrl(_urlController.text) == null) {
      setState(() {
        _errorText = 'Enter a public http or https listing URL.';
      });
      return;
    }

    setState(() {
      _adding = true;
      _errorText = null;
    });
    final result = await ListingUrlCheckerScope.of(context)(
      titleName: widget.titleName,
      url: _urlController.text,
    );
    if (!mounted) {
      return;
    }
    if (!result.isVerifiedLive || result.normalizedUrl == null) {
      setState(() {
        _adding = false;
        _errorText =
            result.errorMessage ??
            'Could not verify that listing page. Check the live URL and try again.';
      });
      return;
    }

    Navigator.of(context).pop(
      applyVerifiedListingLive(
        PlatformStatus.waiting(name),
        checkedAt: DateTime.now(),
        listingUrl: result.normalizedUrl!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final fieldTextStyle = textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final fieldLabelStyle = fieldTextStyle?.copyWith(
      color: colorScheme.onSurface,
      fontWeight: FontWeight.w600,
    );
    final floatingLabelStyle = fieldTextStyle?.copyWith(
      color: colorScheme.onSurface,
      fontWeight: FontWeight.w700,
      fontSize: 12,
      height: 1,
    );
    final fieldDecoration = InputDecoration(
      isDense: true,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: fieldLabelStyle,
      floatingLabelStyle: floatingLabelStyle,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    );
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 56,
                  child: TextField(
                    key: const ValueKey<String>('platform-name-field'),
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    enabled: !_adding,
                    style: fieldTextStyle,
                    decoration: fieldDecoration.copyWith(
                      labelText: 'Channel Name',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey<String>('platform-listing-url-field'),
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  enabled: !_adding,
                  style: fieldTextStyle,
                  onSubmitted: (_) => _submit(),
                  decoration: fieldDecoration.copyWith(
                    labelText: 'Live Title URL (Required for Verification)',
                    errorText: _errorText,
                    errorMaxLines: 3,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const ValueKey<String>('add-platform-button'),
                  onPressed: _adding ? null : _submit,
                  child: Text(_adding ? 'Checking…' : 'Add Manual Channel'),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _adding
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlatformDraftTile extends StatelessWidget {
  const _PlatformDraftTile({
    required this.platform,
    required this.onRemove,
    this.onRemoveLiveStatus,
  });

  final PlatformStatus platform;
  final VoidCallback onRemove;
  final VoidCallback? onRemoveLiveStatus;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final verifiedManual =
        platform.origin == PlatformOrigin.manual &&
        platform.isUserConfirmedAvailability;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text.rich(
              TextSpan(
                style: textTheme.bodyLarge,
                children: [
                  TextSpan(text: platform.platformName),
                  TextSpan(
                    text: ' - ${platform.origin.label}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (_draftSourceLabel(platform) != null) ...[
              const SizedBox(height: 2),
              Text(
                'Source: ${_draftSourceLabel(platform)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      children: [
                        TextSpan(
                          text: platform.statusLabel,
                          style: TextStyle(
                            color: StatusVisuals.of(platform.status).color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (verifiedManual) ...[
                          const TextSpan(text: ' - '),
                          TextSpan(
                            text: 'VERIFIED',
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ] else if (platform.evidenceUrl != null)
                          TextSpan(text: '  ·  ${platform.evidenceUrl}'),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onRemoveLiveStatus != null)
                  TextButton(
                    key: ValueKey<String>(
                      'remove-live-status-${platform.platformName}',
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.fromLTRB(8, 2, 0, 2),
                      textStyle: TextStyle(
                        fontSize: (textTheme.labelLarge?.fontSize ?? 14) - 2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: onRemoveLiveStatus,
                    child: const Text('Remove Live Status'),
                  )
                else
                  IconButton(
                    key: ValueKey<String>(
                      'remove-platform-${platform.platformName}',
                    ),
                    tooltip: 'Remove ${platform.platformName}',
                    visualDensity: VisualDensity.compact,
                    onPressed: onRemove,
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String? _draftSourceLabel(PlatformStatus platform) {
  final url = platform.evidenceUrl?.trim();
  if (url != null && url.isNotEmpty) {
    return url;
  }
  final source = platform.lastMonitoringSource ?? platform.evidenceSource;
  if (source == null ||
      source.trim().isEmpty ||
      source == listingUrlAvailabilitySource) {
    return null;
  }
  return source.trim();
}

String _platformKey(String name) => name.trim().toLowerCase();

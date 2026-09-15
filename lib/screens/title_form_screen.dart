import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:release_status/models/platform_status.dart';
import 'package:release_status/models/release_title.dart';
import 'package:release_status/state/title_catalog.dart';

const int _minimumReleaseYear = 1888;

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
  late final TextEditingController _platformController;

  late List<PlatformStatus> _platforms;
  late Set<String> _originalPlatformKeys;

  String? _contentType;
  String? _contentTypeError;
  String? _platformsError;
  String? _platformEntryError;
  bool _submitted = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingTitle;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _yearController = TextEditingController(
      text: existing == null ? '' : '${existing.releaseYear}',
    );
    _platformController = TextEditingController();
    _contentType = existing?.contentType;
    _platforms = List<PlatformStatus>.from(existing?.platforms ?? const []);
    _originalPlatformKeys = {
      for (final platform in existing?.platforms ?? const <PlatformStatus>[])
        _platformKey(platform.platformName),
    };
  }

  @override
  void dispose() {
    _nameController.dispose();
    _yearController.dispose();
    _platformController.dispose();
    super.dispose();
  }

  int get _maximumReleaseYear => DateTime.now().year + 5;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isCompact = MediaQuery.sizeOf(context).width < 720;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Title' : 'Add Your Title'),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: _submitted
            ? AutovalidateMode.always
            : AutovalidateMode.disabled,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            isCompact ? 20 : 32,
            20,
            isCompact ? 20 : 32,
            40,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.isEditing
                      ? 'Update the title you own, produce, distribute, or control.'
                      : 'Add a movie or TV show you own, produce, distribute, or control.',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  key: const ValueKey<String>('title-name-field'),
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Title name',
                    hintText: 'My Film',
                  ),
                  validator: _validateName,
                ),
                const SizedBox(height: 24),
                Text(
                  'Content type',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      key: const ValueKey<String>('content-type-Movie'),
                      label: const Text('Movie'),
                      selected: _contentType == 'Movie',
                      onSelected: (_) {
                        setState(() {
                          _contentType = 'Movie';
                          _contentTypeError = null;
                        });
                      },
                    ),
                    ChoiceChip(
                      key: const ValueKey<String>('content-type-TV Series'),
                      label: const Text('TV Series'),
                      selected: _contentType == 'TV Series',
                      onSelected: (_) {
                        setState(() {
                          _contentType = 'TV Series';
                          _contentTypeError = null;
                        });
                      },
                    ),
                  ],
                ),
                if (_contentTypeError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _contentTypeError!,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                TextFormField(
                  key: const ValueKey<String>('release-year-field'),
                  controller: _yearController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Release year',
                    hintText: '2024',
                    helperText:
                        'Four-digit year between $_minimumReleaseYear and $_maximumReleaseYear.',
                  ),
                  validator: _validateYear,
                ),
                const SizedBox(height: 32),
                Text(
                  'Licensed Platforms',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Add each platform or channel where this title has been licensed.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                _PlatformEntryRow(
                  controller: _platformController,
                  errorText: _platformEntryError,
                  onAdd: _addPlatform,
                ),
                if (_platformsError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _platformsError!,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                for (var i = 0; i < _platforms.length; i++) ...[
                  _PlatformDraftTile(
                    platform: _platforms[i],
                    onRemove: () => _removePlatform(i),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    key: const ValueKey<String>('save-title-button'),
                    onPressed: _isSaving ? null : _save,
                    child: const Text('Save Title'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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

  void _addPlatform() {
    final result = _tryAddPlatformName(_platformController.text);
    if (result != null) {
      setState(() {
        _platformEntryError = result;
      });
      return;
    }
    setState(() {
      _platformEntryError = null;
      _platformsError = null;
      _platformController.clear();
    });
  }

  String? _tryAddPlatformName(String rawName) {
    final name = rawName.trim();
    if (name.isEmpty) {
      return 'Enter a platform or channel name.';
    }
    if (_platforms.any(
      (platform) => _platformKey(platform.platformName) == _platformKey(name),
    )) {
      return 'That platform is already listed for this title.';
    }
    _platforms = [..._platforms, PlatformStatus.waiting(name)];
    return null;
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

  void _save() {
    if (_isSaving) {
      return;
    }
    setState(() {
      _isSaving = true;
      _submitted = true;
      _platformEntryError = null;
    });

    final pendingName = _platformController.text.trim();
    if (pendingName.isNotEmpty) {
      final pendingError = _tryAddPlatformName(pendingName);
      if (pendingError != null) {
        setState(() {
          _isSaving = false;
          _platformEntryError = pendingError;
        });
        return;
      }
      _platformController.clear();
    }

    final formValid = _formKey.currentState?.validate() ?? false;
    final contentType = _contentType;
    final contentTypeError = contentType == null
        ? 'Select Movie or TV Series.'
        : null;
    final platformsError = _platforms.isEmpty
        ? 'Add at least one licensed platform.'
        : null;

    if (!formValid || contentTypeError != null || platformsError != null) {
      setState(() {
        _isSaving = false;
        _contentTypeError = contentTypeError;
        _platformsError = platformsError;
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
      );
    } else {
      catalog.updateTitle(
        existing.copyWith(
          name: name,
          contentType: contentType,
          releaseYear: year,
          platforms: List<PlatformStatus>.from(_platforms),
        ),
      );
    }

    Navigator.of(context).pop();
  }
}

class _PlatformEntryRow extends StatelessWidget {
  const _PlatformEntryRow({
    required this.controller,
    required this.errorText,
    required this.onAdd,
  });

  final TextEditingController controller;
  final String? errorText;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 560;

    final field = TextField(
      key: const ValueKey<String>('platform-name-field'),
      controller: controller,
      textInputAction: TextInputAction.done,
      textCapitalization: TextCapitalization.words,
      onSubmitted: (_) => onAdd(),
      decoration: InputDecoration(
        labelText: 'Platform or channel name',
        hintText: 'Platform name',
        errorText: errorText,
      ),
    );

    final button = FilledButton.tonal(
      key: const ValueKey<String>('add-platform-button'),
      onPressed: onAdd,
      child: const Text('Add Platform'),
    );

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [field, const SizedBox(height: 12), button],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: field),
        const SizedBox(width: 12),
        Padding(padding: const EdgeInsets.only(top: 8), child: button),
      ],
    );
  }
}

class _PlatformDraftTile extends StatelessWidget {
  const _PlatformDraftTile({required this.platform, required this.onRemove});

  final PlatformStatus platform;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
        child: Row(
          children: [
            Icon(
              Icons.tv_outlined,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                platform.platformName,
                style: textTheme.bodyLarge,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              key: ValueKey<String>('remove-platform-${platform.platformName}'),
              tooltip: 'Remove ${platform.platformName}',
              onPressed: onRemove,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

String _platformKey(String name) => name.trim().toLowerCase();

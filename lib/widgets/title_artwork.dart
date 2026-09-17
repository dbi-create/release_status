import 'package:flutter/material.dart';

import 'package:release_status/models/release_title.dart';

/// TMDb poster images are 2:3 (width:height), not square.
const double tmdbPosterAspectRatio = 2 / 3;

/// Shows a TMDb poster URL when we have one. Does not save image files.
class TitleArtwork extends StatelessWidget {
  const TitleArtwork({super.key, required this.title, this.size = 64});

  final ReleaseTitle title;

  /// Poster width. Height is derived from [tmdbPosterAspectRatio].
  final double size;

  double get _height => size / tmdbPosterAspectRatio;

  @override
  Widget build(BuildContext context) {
    final posterUrl = title.posterUrl;
    return Semantics(
      label: posterUrl == null
          ? '${title.name} placeholder artwork'
          : '${title.name} poster',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: size,
          height: _height,
          child: posterUrl == null
              ? _Monogram(title: title, height: _height)
              : Image.network(
                  posterUrl,
                  width: size,
                  height: _height,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (context, error, stackTrace) {
                    return _Monogram(title: title, height: _height);
                  },
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) {
                      return child;
                    }
                    return _Monogram(title: title, height: _height);
                  },
                ),
        ),
      ),
    );
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({required this.title, required this.height});

  final ReleaseTitle title;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: title.placeholderColor,
      child: Center(
        child: Text(
          title.initials,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            fontSize: height >= 80 ? 22 : 16,
          ),
        ),
      ),
    );
  }
}

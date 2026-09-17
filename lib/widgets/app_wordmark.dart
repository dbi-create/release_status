import 'package:flutter/material.dart';

import 'package:release_status/widgets/platform_status_row.dart';

/// Centered iOS app title and colored slogan.
class AppWordmark extends StatelessWidget {
  const AppWordmark({super.key, this.trailing});

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final sloganStyle = textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      height: 1.35,
    );
    final titleStyle = textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
    );
    final trailing = this.trailing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'RELEASE STATUS',
                textAlign: TextAlign.left,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'YOUR TITLES',
                style: sloganStyle?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Text(' | ', style: sloganStyle),
              Text(
                'YOUR PLATFORMS',
                style: sloganStyle?.copyWith(color: StatusVisuals.live.color),
              ),
              Text(' | ', style: sloganStyle),
              Text(
                'YOUR STATUS',
                style: sloganStyle?.copyWith(color: StatusVisuals.waiting.color),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

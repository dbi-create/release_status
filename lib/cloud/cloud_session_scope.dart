import 'package:flutter/material.dart';

import 'package:release_status/cloud/cloud_session.dart';

class CloudSessionScope extends InheritedNotifier<CloudSession> {
  const CloudSessionScope({
    super.key,
    required CloudSession session,
    required super.child,
  }) : super(notifier: session);

  static CloudSession of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CloudSessionScope>();
    assert(scope != null, 'CloudSessionScope not found in context');
    return scope!.notifier!;
  }

  static CloudSession? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<CloudSessionScope>()
        ?.notifier;
  }
}

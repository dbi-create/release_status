import 'package:flutter/material.dart';

import 'package:release_status/monitoring/listing_url_verifier.dart';

class ListingUrlCheckerScope extends InheritedWidget {
  const ListingUrlCheckerScope({
    super.key,
    required this.checker,
    required super.child,
  });

  final ListingUrlChecker checker;

  static ListingUrlChecker of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<ListingUrlCheckerScope>();
    return scope?.checker ?? fetchAndVerifyListingUrl;
  }

  @override
  bool updateShouldNotify(ListingUrlCheckerScope oldWidget) {
    return checker != oldWidget.checker;
  }
}

enum PlatformOrigin { manual, automatic }

extension PlatformOriginLabel on PlatformOrigin {
  String get label {
    switch (this) {
      case PlatformOrigin.manual:
        return 'Added Manually';
      case PlatformOrigin.automatic:
        return 'Added Automatically';
    }
  }
}

PlatformOrigin platformOriginFromName(String? name) {
  if (name == PlatformOrigin.automatic.name) {
    return PlatformOrigin.automatic;
  }
  return PlatformOrigin.manual;
}

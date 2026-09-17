/// What ReleaseStatus knows about the licensing relationship.
///
/// Availability evidence never implies a Filmhub or distributor license.
enum LicenseRelationship { confirmedByUser, unknown }

extension LicenseRelationshipLabel on LicenseRelationship {
  String get label {
    switch (this) {
      case LicenseRelationship.confirmedByUser:
        return 'Confirmed by you';
      case LicenseRelationship.unknown:
        return 'License unknown';
    }
  }
}

LicenseRelationship licenseRelationshipFromName(String? name) {
  if (name == LicenseRelationship.unknown.name) {
    return LicenseRelationship.unknown;
  }
  return LicenseRelationship.confirmedByUser;
}

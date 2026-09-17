/// Conservative LIVE → REMOVED confirmation.
///
/// Only consecutive VERIFIED absences count. Network errors, API errors,
/// ambiguous matches, and possible matches never increment this counter.
class RemovalConfirmationPolicy {
  const RemovalConfirmationPolicy({
    this.requiredConsecutiveVerifiedAbsences =
        defaultRequiredConsecutiveVerifiedAbsences,
  });

  /// Standard production threshold. Kept in one place so UI, apply logic,
  /// and tests share the same number.
  static const int defaultRequiredConsecutiveVerifiedAbsences = 3;

  static const RemovalConfirmationPolicy standard = RemovalConfirmationPolicy();

  final int requiredConsecutiveVerifiedAbsences;

  bool confirmsRemoval(int consecutiveVerifiedAbsences) {
    return consecutiveVerifiedAbsences >= requiredConsecutiveVerifiedAbsences;
  }
}

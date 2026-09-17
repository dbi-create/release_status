class LiveAlert {
  const LiveAlert({
    required this.titleName,
    required this.platformName,
    this.titleId,
  });

  final String titleName;
  final String platformName;
  final String? titleId;
}

String liveAlertHeadline(List<LiveAlert> alerts) {
  if (alerts.isEmpty) {
    return 'Release Status';
  }
  final titles = {for (final alert in alerts) alert.titleName};
  if (titles.length == 1) {
    return '${titles.first} is live';
  }
  return '${titles.length} titles went live';
}

String liveAlertBody(List<LiveAlert> alerts) {
  if (alerts.isEmpty) {
    return '';
  }
  final byTitle = <String, List<String>>{};
  for (final alert in alerts) {
    byTitle.putIfAbsent(alert.titleName, () => []).add(alert.platformName);
  }
  if (byTitle.length == 1) {
    final platforms = byTitle.values.first.join(', ');
    return 'Now live on $platforms.';
  }
  return byTitle.entries
      .map((entry) => '${entry.key}: ${entry.value.join(', ')}')
      .join(' · ');
}

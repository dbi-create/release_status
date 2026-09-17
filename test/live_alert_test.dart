import 'package:flutter_test/flutter_test.dart';

import 'package:release_status/notifications/live_alert.dart';

void main() {
  test('one title formats a live headline and platforms', () {
    const alerts = [
      LiveAlert(titleName: 'The Rookie', platformName: 'Hulu'),
      LiveAlert(titleName: 'The Rookie', platformName: 'Disney+'),
    ];
    expect(liveAlertHeadline(alerts), 'The Rookie is live');
    expect(liveAlertBody(alerts), 'Now live on Hulu, Disney+.');
  });

  test('multiple titles summarize in the headline', () {
    const alerts = [
      LiveAlert(titleName: 'Marked', platformName: 'Plex'),
      LiveAlert(titleName: 'The Rookie', platformName: 'Hulu'),
    ];
    expect(liveAlertHeadline(alerts), '2 titles went live');
    expect(liveAlertBody(alerts), 'Marked: Plex · The Rookie: Hulu');
  });
}

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:release_status/cloud/cloud_session.dart';
import 'package:release_status/cloud/push_tokens.dart';
import 'package:release_status/notifications/live_alert.dart';

const _channel = MethodChannel('release_status/push');

class LiveAlertFanOut {
  const LiveAlertFanOut({required this.sent, this.reason, this.tokenCount = 0});

  final int sent;
  final String? reason;
  final int tokenCount;
}

class LiveAlertService {
  LiveAlertService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static final LiveAlertService instance = LiveAlertService();

  final FlutterLocalNotificationsPlugin _plugin;
  final String deviceId = _newDeviceId();
  Future<void>? _ready;
  RealtimeChannel? _inbox;
  String? _inboxUserId;

  Future<void> ensureReady() async {
    final existing = _ready;
    if (existing != null) {
      await existing;
      return;
    }
    final pending = _initialize();
    _ready = pending;
    try {
      await pending;
    } on Object {
      _ready = null;
      rethrow;
    }
  }

  Future<void> handle(List<LiveAlert> alerts) async {
    if (alerts.isEmpty) {
      return;
    }
    try {
      await ensureReady();
      await _show(alerts);
      await fanOutLiveAlert(alerts, deviceId: deviceId, inbox: _inbox);
    } on Object {
      // Missing plugin in tests, or OS permission denied.
    }
  }

  Future<LiveAlertFanOut> showTest() async {
    try {
      await ensureReady();
    } on Object {
      // Token save can fail; the test banner and phone push should still send.
    }
    const alerts = [
      LiveAlert(titleName: 'Test title', platformName: 'Test channel'),
    ];
    await _show(alerts);
    return fanOutLiveAlert(alerts, deviceId: deviceId, inbox: _inbox);
  }

  Future<void> listenForAccount(String? userId) async {
    await ensureReady();
    if (userId == null || userId.isEmpty) {
      await _inbox?.unsubscribe();
      _inbox = null;
      _inboxUserId = null;
      return;
    }
    if (_inboxUserId == userId && _inbox != null) {
      unawaited(registerCurrentDeviceToken());
      return;
    }
    await _inbox?.unsubscribe();
    _inboxUserId = userId;
    unawaited(registerCurrentDeviceToken());
    final client = releaseStatusCloudClient();
    if (client == null) {
      return;
    }
    _inbox = client.channel(
      'release_status_alert_$userId',
      opts: const RealtimeChannelConfig(self: false),
    )..onBroadcast(
        event: 'live_alert',
        callback: (payload) {
          final data = _broadcastFields(payload);
          if (data['source_device_id'] == deviceId) {
            return;
          }
          unawaited(
            _showRaw(
              headline: data['headline'] ?? 'Release Status',
              body: data['body'] ?? '',
            ),
          );
        },
      )
      ..subscribe();
  }

  Future<void> _initialize() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'tokenUpdated') {
        final token = call.arguments as String?;
        if (token != null && token.isNotEmpty) {
          try {
            await rememberAndSavePushToken(token);
          } on Object {
            // Duplicate token is already stored.
          }
        }
      }
    });
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: darwin,
        macOS: darwin,
      ),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    await _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    try {
      await _channel.invokeMethod<void>('register');
      await registerCurrentDeviceToken();
    } on Object {
      // Duplicate token rows must not block sending a test or live alert.
    }
  }

  Future<void> _show(List<LiveAlert> alerts) {
    return _showRaw(
      headline: liveAlertHeadline(alerts),
      body: liveAlertBody(alerts),
    );
  }

  Future<void> _showRaw({required String headline, required String body}) async {
    const darwin = DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentList: true,
      presentSound: true,
    );
    await _plugin.show(
      id: 91017,
      title: headline,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'live_titles',
          'Live titles',
          channelDescription: 'When a title becomes live on a platform.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: darwin,
        macOS: darwin,
      ),
    );
  }
}

String _newDeviceId() {
  final random = Random.secure();
  return List<String>.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

Map<String, String> _broadcastFields(Map<String, dynamic> payload) {
  final nested = payload['payload'];
  final source = nested is Map<String, dynamic> ? nested : payload;
  return {
    'headline': '${source['headline'] ?? ''}',
    'body': '${source['body'] ?? ''}',
    'source_device_id': '${source['source_device_id'] ?? ''}',
  };
}

Future<void> registerCurrentDeviceToken() async {
  try {
    final cached = cachedPushToken();
    if (cached != null && cached.isNotEmpty) {
      await upsertPushToken(cached);
    }
    for (var attempt = 0; attempt < 20; attempt++) {
      final token = await _channel.invokeMethod<String>('getApnsToken');
      if (token != null && token.isNotEmpty) {
        await rememberAndSavePushToken(token);
        return;
      }
      await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
    }
  } on MissingPluginException {
    return;
  } on Object {
    return;
  }
}

Future<LiveAlertFanOut> fanOutLiveAlert(
  List<LiveAlert> alerts, {
  required String deviceId,
  RealtimeChannel? inbox,
}) async {
  final client = releaseStatusCloudClient();
  final userId = client?.auth.currentUser?.id;
  if (client == null || userId == null) {
    return const LiveAlertFanOut(sent: 0, reason: 'not_signed_in');
  }
  try {
    final channel =
        inbox ??
        client.channel(
          'release_status_alert_$userId',
          opts: const RealtimeChannelConfig(self: false),
        );
    await channel.sendBroadcastMessage(
      event: 'live_alert',
      payload: {
        'headline': liveAlertHeadline(alerts),
        'body': liveAlertBody(alerts),
        'source_device_id': deviceId,
      },
    );
  } on Object {
    // Realtime is optional if the session is not connected.
  }
  try {
    final response = await client.functions.invoke(
      'release-status-notify',
      body: {
        'title': liveAlertHeadline(alerts),
        'body': liveAlertBody(alerts),
        'claimed': true,
        'skipClaim': true,
        'alerts': [
          for (final alert in alerts)
            {
              'titleId': alert.titleId,
              'titleName': alert.titleName,
              'platformName': alert.platformName,
            },
        ],
      },
    );
    final data = _functionData(response.data);
    if (data != null) {
      final sent = data['sent'];
      final tokenCount = data['tokenCount'];
      return LiveAlertFanOut(
        sent: sent is int ? sent : int.tryParse('$sent') ?? 0,
        tokenCount: tokenCount is int
            ? tokenCount
            : int.tryParse('$tokenCount') ?? 0,
        reason: data['reason'] as String?,
      );
    }
    return const LiveAlertFanOut(sent: 0, reason: 'bad_push_response');
  } on Object catch (error) {
    return LiveAlertFanOut(sent: 0, reason: '$error');
  }
}

Map<String, dynamic>? _functionData(Object? data) {
  if (data is Map<String, dynamic>) {
    return data;
  }
  if (data is Map) {
    return Map<String, dynamic>.from(data);
  }
  if (data is String && data.isNotEmpty) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } on Object {
      return null;
    }
  }
  return null;
}

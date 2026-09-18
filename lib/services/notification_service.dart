import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      tz.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation('Africa/Lome'));
      } catch (_) {
        // Keep the timezone package default if the device data lacks Africa/Lome.
      }
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const settings = InitializationSettings(android: android);
      await _plugin.initialize(settings: settings);
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'medication_reminders',
          'Rappels de médicaments',
          description: 'Rappels des prises prescrites',
          importance: Importance.high,
        ),
      );
      _initialized = true;
    } catch (_) {
      // Notifications must never prevent the application UI from starting.
    }
  }

  Future<bool> requestPermission() async {
    if (!_initialized) await init();
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await androidPlugin?.requestNotificationsPermission() ?? false;
  }

  Future<void> syncMedicationReminders(
    List<Map<String, dynamic>> medicines,
  ) async {
    if (!_initialized) return;
    await _plugin.cancelAll();
    for (var index = 0; index < medicines.length; index++) {
      final medicine = medicines[index];
      final count = _frequencyCount(medicine['frequence']?.toString() ?? '');
      final times = count == 3
          ? const [8, 14, 20]
          : count == 2
          ? const [8, 20]
          : const [8];
      for (var timeIndex = 0; timeIndex < times.length; timeIndex++) {
        final next = _nextTime(times[timeIndex]);
        try {
          await _plugin.zonedSchedule(
            id: index * 10 + timeIndex,
            title: 'Rappel médicament',
            body:
                '${medicine['nom'] ?? 'Médicament'} - ${medicine['dose'] ?? ''}',
            scheduledDate: next,
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                'medication_reminders',
                'Rappels de médicaments',
                channelDescription: 'Rappels des prises prescrites',
                importance: Importance.high,
                priority: Priority.high,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.time,
          );
        } catch (_) {
          // A reminder failure must not affect dossier loading.
        }
      }
    }
  }

  int _frequencyCount(String frequency) {
    final match = RegExp(r'(\d+)\s*fois').firstMatch(frequency.toLowerCase());
    return int.tryParse(match?.group(1) ?? '') ?? 1;
  }

  tz.TZDateTime _nextTime(int hour) {
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);
    if (next.isBefore(now)) next = next.add(const Duration(days: 1));
    return next;
  }
}

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Must be top-level for background isolate
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase already initialized in main; nothing extra needed here.
}

class NotificationService {
  static final _fcm = FirebaseMessaging.instance;
  static final _local = FlutterLocalNotificationsPlugin();

  static const _channelId = 'discim_channel';
  static const _channelName = 'Dişçim Bildirimleri';

  static const _channel = AndroidNotificationChannel(
    _channelId,
    _channelName,
    description: 'Randevu ve mesaj bildirimleri',
    importance: Importance.high,
  );

  static Future<void> init() async {
    // Permission (Android 13+ + iOS) — non-critical, hata olursa devam et
    try {
      await _fcm.requestPermission(alert: true, badge: true, sound: true);
    } catch (_) {}

    // Create Android notification channel
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // Init flutter_local_notifications (Android + iOS)
    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );

    // Foreground: show local notification manually (FCM doesn't auto-show in foreground)
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final n = message.notification;
      if (n == null) return;
      _local.show(
        n.hashCode,
        n.title,
        n.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    });
  }

  static Future<void> showLocalNotification({required String title, required String body}) async {
    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  static Future<void> checkUpcomingAppointments(String uid) async {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final tStr = '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';

    final snap = await FirebaseFirestore.instance
        .collection('appointments')
        .where('userId', isEqualTo: uid)
        .where('status', isEqualTo: 'confirmed')
        .get();

    for (final doc in snap.docs) {
      final data = doc.data();
      final date = (data['date'] as Timestamp).toDate();
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      if (dateStr == tStr) {
        await showLocalNotification(
          title: 'Yarın randevunuz var! 🦷',
          body: '${data['clinicName']} kliniğinde saat ${data['time']} - ${data['treatmentType']}',
        );
      }
    }
  }

  static Future<void> saveTokenForUser(String uid) async {
    final token = await _fcm.getToken();
    if (token == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'fcmToken': token});

    _fcm.onTokenRefresh.listen((newToken) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'fcmToken': newToken});
    });
  }

  static Future<void> saveTokenForClinic(String clinicId) async {
    final token = await _fcm.getToken();
    if (token == null) return;
    await FirebaseFirestore.instance
        .collection('clinics')
        .doc(clinicId)
        .update({'fcmToken': token});

    _fcm.onTokenRefresh.listen((newToken) {
      FirebaseFirestore.instance
          .collection('clinics')
          .doc(clinicId)
          .update({'fcmToken': newToken});
    });
  }
}

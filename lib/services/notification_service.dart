import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../database/db_helper.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  // Ежедневная генерация сводного уведомления
  Future<void> checkAndScheduleDailySummary() async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();

    // 1. Поиск тех, кого надо покормить
    final animals = await db.rawQuery('''
      SELECT a.name, MAX(f.date) as last_feed, a.feeding_interval_days
      FROM animals a
      LEFT JOIN feedings f ON a.id = f.animal_id AND f.status = 'eaten'
      GROUP BY a.id
    ''');

    List<String> needFeeding = [];
    for (var a in animals) {
      if (a['last_feed'] == null) {
        needFeeding.add(a['name'] as String);
      } else {
        final lastDate = DateTime.parse(a['last_feed'] as String);
        final interval = a['feeding_interval_days'] as int;
        if (now.difference(lastDate).inDays >= interval) {
          needFeeding.add(a['name'] as String);
        }
      }
    }

    // 2. Поиск ламп под замену (старше срока)
    final expiredLamps = await db.rawQuery('''
      SELECT name FROM animals 
      WHERE DATE(uv_lamp_install_date, '+' || uv_lamp_lifespan_months || ' month') <= DATE('now')
    ''');

    // Формирование единого сводного уведомления
    String message = "";
    if (needFeeding.isNotEmpty) {
      message += "🍽 Покормить (${needFeeding.length}): ${needFeeding.join(', ')}. ";
    }
    if (expiredLamps.isNotEmpty) {
      message += "💡 Замена УФ-ламп у: ${expiredLamps.map((e) => e['name']).join(', ')}.";
    }

    if (message.isNotEmpty) {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'exo_summary',
        'Сводные уведомления',
        channelDescription: 'Сводка по кормлениям и оборудованию на день',
        importance: Importance.max,
        priority: Priority.high,
      );
      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      await flutterLocalNotificationsPlugin.show(
        0,
        'План по питомцам на сегодня',
        message,
        platformChannelSpecifics,
      );
    }
  }
}
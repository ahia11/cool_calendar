// lib/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart'; 
import 'dart:io';
import 'package:flutter/foundation.dart'; // 用于 debugPrint

class NotificationService {
  // 单例模式
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // 1. 初始化
  Future<void> init() async {
    // 初始化时区数据库
    tz.initializeTimeZones();
    
    // 获取并设置本地时区 (解决时区不对导致不响的问题)
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      debugPrint(">>> 时区已设置为: $timeZoneName");
    } catch (e) {
      debugPrint(">>> 获取时区失败，使用默认 UTC: $e");
      tz.setLocalLocation(tz.getLocation('UTC')); 
    }

    // Android 设置
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint("Notification clicked: ${response.payload}");
      },
    );

    // 申请权限 (Android 13+)
    if (Platform.isAndroid) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  // 2. 安排定时通知 (核心修改部分)
  Future<void> scheduleNotification(int id, String title, String body, DateTime scheduledTime) async {
    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local), // 使用正确的本地时区
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'channel_id_calendar_vip', // 🔥 修改 1: 改了 ID，强制系统重建渠道
            '重要日程提醒',                // 🔥 修改 2: 改了名字
            channelDescription: '日历日程的高优先级提醒',
            importance: Importance.max, // 🔥 确保最高重要性 (决定是否弹窗)
            priority: Priority.high,    // 🔥 确保最高优先级
            ticker: '日程提醒',
            fullScreenIntent: true,     // 尝试申请全屏显示
            playSound: true,            // 确保有声音
            enableVibration: true,      // 确保震动
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // 即使在低电量模式也提醒
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint(">>> 成功：通知已设定在 $scheduledTime (本地时区)");
    } catch (e) {
      debugPrint(">>> 致命错误：设定通知失败！原因: $e");
    }
  }

  // 3. 取消通知
  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }
}
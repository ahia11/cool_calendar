// lib/providers/event_provider.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:icalendar_parser/icalendar_parser.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/event_model.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';

// 定义订阅源的数据结构
class SubscriptionSource {
  final String name; 
  final String url;
  final bool isEnabled; 

  SubscriptionSource({required this.name, required this.url, this.isEnabled = true});

  Map<String, dynamic> toJson() => {'name': name, 'url': url, 'isEnabled': isEnabled};
  factory SubscriptionSource.fromJson(Map<String, dynamic> json) => 
      SubscriptionSource(name: json['name'] ?? '', url: json['url'], isEnabled: json['isEnabled'] ?? true);
}


class EventProvider extends ChangeNotifier {
  Map<DateTime, List<Event>> _events = {}; 
  Map<DateTime, List<Event>> get events => _events;

  static const _subscriptionKey = 'calendar_subscriptions';

  // --- 核心方法 ---

  // 1. 加载数据
  Future<void> loadEvents() async {
    final eventList = await DatabaseHelper.instance.readAllEvents();
    _events = {};
    for (var event in eventList) {
      final dateKey = DateTime(event.date.year, event.date.month, event.date.day);
      if (_events[dateKey] == null) {
        _events[dateKey] = [];
      }
      _events[dateKey]!.add(event);
    }
    notifyListeners();
  }

  // 2. 添加日程
  Future<void> addEvent(Event event) async {
    await DatabaseHelper.instance.createEvent(event);
    if (!event.isAllDay && event.date.isAfter(DateTime.now())) {
      final int notificationId = event.date.millisecondsSinceEpoch.remainder(100000);
      await NotificationService().scheduleNotification(
        notificationId,
        "日程提醒: ${event.title}",
        event.description ?? "您有一个待办事项",
        event.date,
      );
    }
    await loadEvents();
  }

  // 3. 删除日程
  Future<void> deleteEvent(Event event) async {
    await DatabaseHelper.instance.deleteEvent(event.id);
    if (!event.isAllDay) {
      final int notificationId = event.date.millisecondsSinceEpoch.remainder(100000);
      await NotificationService().cancelNotification(notificationId);
    }
    await loadEvents();
  }

  // 4. 更新日程
  Future<void> updateEvent(Event oldEvent, Event newEvent) async {
    await DatabaseHelper.instance.updateEvent(newEvent);

    if (!oldEvent.isAllDay) {
      final int oldNotificationId = oldEvent.date.millisecondsSinceEpoch.remainder(100000);
      await NotificationService().cancelNotification(oldNotificationId);
    }

    if (!newEvent.isAllDay && newEvent.date.isAfter(DateTime.now())) {
      final int newNotificationId = newEvent.date.millisecondsSinceEpoch.remainder(100000);
      await NotificationService().scheduleNotification(
        newNotificationId,
        "日程提醒: ${newEvent.title}",
        newEvent.description ?? "日程已更新",
        newEvent.date,
      );
    }
    await loadEvents();
  }
  
  // 5. 获取某天的日程列表
  List<Event> getEventsForDay(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    return _events[dateKey] ?? [];
  }

  // 6. 获取某天的颜色标记列表 (已修复：确保返回 Color 对象)
  List<Color> getSchemeColorsForDay(DateTime day) {
    final events = getEventsForDay(day);
    if (events.isEmpty) {
      return [];
    }
    
    final Set<Color> schemeColors = {};
    const defaultLocalColor = Color(0xFF5E5CE6); // 默认本地事件颜色 (紫色)
    
    for (var event in events) {
      Color eventColor;

      // 核心修复：直接将 int? 转换为 Color，如果为 null 则使用默认色
      if (event.colorValue != null) {
          eventColor = Color(event.colorValue!);
      } else {
        // 如果 colorValue 为空，则使用默认本地色
        eventColor = defaultLocalColor;
      }
      
      schemeColors.add(eventColor);
    }
    // 限制最多显示 3 个颜色标记
    return schemeColors.take(3).toList(); 
  }


  // --- 订阅管理方法 ---

  Future<void> _saveSubscription(String url, {String? sourceName}) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> savedList = prefs.getStringList(_subscriptionKey) ?? [];
    
    // 检查是否已存在
    if (savedList.any((jsonStr) => SubscriptionSource.fromJson(jsonDecode(jsonStr)).url == url)) {
        return;
    }

    // 确定最终名称：如果用户提供了，则使用用户提供的名称，否则使用截断的 URL
    final String finalName = sourceName?.trim().isNotEmpty == true 
        ? sourceName! 
        : (url.length > 50 ? "${url.substring(0, 47)}..." : url);

    final newSubscription = SubscriptionSource(name: finalName, url: url);
    
    savedList.add(jsonEncode(newSubscription.toJson()));
    await prefs.setStringList(_subscriptionKey, savedList);
  }

  Future<List<SubscriptionSource>> getSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> savedList = prefs.getStringList(_subscriptionKey) ?? [];
    return savedList.map((jsonStr) => SubscriptionSource.fromJson(jsonDecode(jsonStr))).toList();
  }

  // 7. 删除订阅源及其所有日程
  Future<void> deleteSubscriptionSource(BuildContext context, String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> savedList = prefs.getStringList(_subscriptionKey) ?? [];

      // 1. 从本地存储中删除 URL
      final newList = savedList.where((jsonStr) => 
          SubscriptionSource.fromJson(jsonDecode(jsonStr)).url != url
      ).toList();

      await prefs.setStringList(_subscriptionKey, newList);

      // 2. 从数据库中删除所有订阅事件
      final allEvents = await DatabaseHelper.instance.readAllEvents();
      int deleteCount = 0;
      
      for (var event in allEvents) {
        if (event.isSubscribed) {
          await DatabaseHelper.instance.deleteEvent(event.id);
          deleteCount++;
        }
      }

      // 3. 刷新 UI
      await loadEvents();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("已删除订阅源并移除了 $deleteCount 个日程")),
        );
      }
    } catch (e) {
       if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("删除订阅源失败: $e")),
        );
      }
    }
  }


  // --- 导入/导出/订阅方法 ---

  // 8. 导出功能
  Future<void> exportEvents(BuildContext context) async {
    try {
      final allEvents = await DatabaseHelper.instance.readAllEvents();
      
      if (!context.mounted) return;

      if (allEvents.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("没有日程可导出")),
        );
        return;
      }

      final String jsonStr = jsonEncode(allEvents.map((e) => e.toMap()).toList());
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/calendar_backup_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonStr);

      await Share.shareXFiles([XFile(file.path)], text: '这是我的日历备份文件');
      
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("导出失败: $e")),
      );
    }
  }

  // 9. 导入功能
  Future<void> importEvents(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (!context.mounted) return;

      if (result != null && result.files.single.path != null) {
        final File file = File(result.files.single.path!);
        
        final String jsonStr = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(jsonStr);

        int count = 0;
        for (var jsonItem in jsonList) {
          final event = Event.fromMap(jsonItem);
          await DatabaseHelper.instance.createEvent(event);
          count++;
          
          if (!event.isAllDay && event.date.isAfter(DateTime.now())) {
            final int notificationId = event.date.millisecondsSinceEpoch.remainder(100000);
            await NotificationService().scheduleNotification(
              notificationId,
              "日程提醒: ${event.title}",
              event.description ?? "已恢复的日程",
              event.date,
            );
          }
        }

        await loadEvents();

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("成功导入 $count 条日程")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("导入失败: 文件格式错误或损坏")),
        );
      }
    }
  }

  // 10. 网络订阅功能
  Future<void> subscribeToCalendar(BuildContext context, String url, {String? sourceName}) async {
    try {
      if (url.isEmpty) return;
      if (url.startsWith('webcal://')) {
        url = url.replaceFirst('webcal://', 'https://');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("正在下载日历数据...")),
      );

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final String icsString = const Utf8Decoder().convert(response.bodyBytes);
        final ICalendar iCalendar = ICalendar.fromString(icsString);
        
        int count = 0;
        
        // 默认订阅事件的颜色值
        final defaultSubscribedColorValue = Colors.blue.shade600.value;
        
        if (iCalendar.data != null) {
          for (var item in iCalendar.data!) {
            if (item['type'] == 'VEVENT') {
              try {
                final String title = item['summary'] ?? '无标题事件';
                final String description = item['description'] ?? '';
                
                DateTime? eventDate;
                var dtstart = item['dtstart'];
                
                // 修复：移除不必要的 null 检查
                if (dtstart is IcsDateTime) {
                    eventDate = dtstart.toDateTime();
                } else if (dtstart is String) {
                    eventDate = DateTime.tryParse(dtstart);
                }

                if (eventDate == null) continue;

                final event = Event(
                  id: const Uuid().v4(),
                  title: title,
                  description: "$description (来自订阅)",
                  date: eventDate,
                  isAllDay: true,
                  isSubscribed: true, 
                  colorValue: defaultSubscribedColorValue, // 设定默认颜色值
                );

                await DatabaseHelper.instance.createEvent(event);
                count++;
              } catch (e) {
                debugPrint("解析单个事件失败: $e");
                continue;
              }
            }
          }
        }

        // 成功后保存 URL 和用户备注
        await _saveSubscription(url, sourceName: sourceName); 
        
        await loadEvents();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("订阅成功！已添加 $count 个事件")),
          );
        }
      } else {
        throw Exception("网络请求失败: ${response.statusCode}");
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("订阅失败: $e")),
        );
      }
    }
  }
}
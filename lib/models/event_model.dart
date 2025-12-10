// lib/models/event_model.dart
class Event {
  final String id;
  final String title;
  final String? description;
  final DateTime date;
  final bool isAllDay;
  final bool isSubscribed;
  final int? colorValue; // 新增字段：用于存储颜色整数值 (如 Colors.blue.value)

  const Event({
    required this.id,
    required this.title,
    this.description,
    required this.date,
    this.isAllDay = false,
    this.isSubscribed = false,
    this.colorValue, // 默认不设置颜色
  });

  // 从数据库读取
  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      date: DateTime.parse(map['date'] as String),
      isAllDay: (map['is_all_day'] as int) == 1,
      isSubscribed: (map['is_subscribed'] as int) == 1,
      colorValue: map['color_value'] as int?, // 读取颜色值
    );
  }

  // 存入数据库
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'is_all_day': isAllDay ? 1 : 0,
      'is_subscribed': isSubscribed ? 1 : 0,
      'color_value': colorValue, // 写入颜色值
    };
  }

  // 用于更新操作（可选但推荐）
  Event copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? date,
    bool? isAllDay,
    bool? isSubscribed,
    int? colorValue,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      isAllDay: isAllDay ?? this.isAllDay,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      colorValue: colorValue ?? this.colorValue,
    );
  }
}
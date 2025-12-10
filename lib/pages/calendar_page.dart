// lib/pages/calendar_page.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:lunar/lunar.dart';
import '../providers/event_provider.dart';
import '../models/event_model.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> with SingleTickerProviderStateMixin {
  // 视图状态变量
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // 动画控制器和动画值，用于日历收缩/展开
  late final AnimationController _animationController;
  late final Animation<double> _animation;

  // 可选的标签颜色列表
  final List<Color> _availableColors = [
    const Color(0xFF5E5CE6), // Purple (Default)
    Colors.redAccent,
    Colors.orange,
    Colors.green,
    Colors.blue.shade600,
    Colors.pink,
  ];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    
    // 初始化动画控制器
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = Tween<double>(begin: 1.0, end: 0.0).animate(_animationController);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<EventProvider>(context, listen: false).loadEvents();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // 切换日历视图的方法 (核心交互)
  void _toggleCalendarFormat() {
    setState(() {
      if (_calendarFormat == CalendarFormat.month) {
        _calendarFormat = CalendarFormat.week;
        _animationController.forward(from: 0.0); // 播放动画，月到周
      } else {
        _calendarFormat = CalendarFormat.month;
        _animationController.reverse(from: 1.0); // 逆转动画，周到月
      }
    });
  }

  // ==========================
  // 自定义日历格子 (多颜色标记)
  // ==========================
  Widget _buildCalendarCell(DateTime day, {bool isSelected = false, bool isToday = false}) {
    final eventProvider = Provider.of<EventProvider>(context);
    final schemeColors = eventProvider.getSchemeColorsForDay(day);

    Lunar lunar = Lunar.fromDate(day);
    String lunarText = lunar.getDayInChinese();
    if (lunar.getDay() == 1) lunarText = "${lunar.getMonthInChinese()}月";
    
    bool isHoliday = false;
    List<String> festivals = lunar.getFestivals();
    if (festivals.isNotEmpty) {
      lunarText = festivals[0];
      isHoliday = true;
    }

    return Container(
      margin: const EdgeInsets.all(4.0),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF5E5CE6) : Colors.transparent,
        border: isToday && !isSelected 
            ? Border.all(color: const Color(0xFF5E5CE6), width: 1.5) 
            : null,
        shape: BoxShape.circle,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 1. 公历/农历显示区域
          Text(
            '${day.day}',
            style: TextStyle(
              color: isSelected 
                  ? Colors.white 
                  : (isToday ? const Color(0xFF5E5CE6) : Colors.black87),
              fontWeight: isSelected || isToday ? FontWeight.w600 : FontWeight.normal,
              fontSize: 16,
            ),
          ),
          Text(
            lunarText,
            style: TextStyle(
              color: isSelected 
                  ? Colors.white.withOpacity(0.8) 
                  : (isHoliday ? Colors.redAccent : Colors.grey),
              fontSize: 9,
              fontWeight: isHoliday ? FontWeight.bold : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          
          // 2. 多颜色标记区域 (使用 schemeColors 列表中的颜色)
          if (schemeColors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: schemeColors.map((color) {
                  return Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: color, 
                      shape: BoxShape.circle,
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // ==========================
  // 添加/编辑 日程弹窗 (增加颜色选择器)
  // ==========================
  void _showAddEventDialog({Event? eventToEdit}) {
    final titleController = TextEditingController(text: eventToEdit?.title ?? '');
    final descController = TextEditingController(text: eventToEdit?.description ?? '');
    final now = DateTime.now();
    DateTime baseDate = eventToEdit?.date ?? _selectedDay ?? now;
    if (eventToEdit == null) {
      baseDate = DateTime(baseDate.year, baseDate.month, baseDate.day, now.hour, now.minute);
    }
    DateTime selectedDateTime = baseDate;
    bool isAllDay = eventToEdit?.isAllDay ?? true; 
    
    final bool isSubscribed = eventToEdit?.isSubscribed ?? false;
    
    // 初始化选中的颜色 (如果没有设置，使用默认主题色)
    Color selectedColor = eventToEdit?.colorValue != null 
        ? Color(eventToEdit!.colorValue!) 
        : _availableColors[0]; 


    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Center(
                child: Text(
                  eventToEdit == null ? '新建日程' : '编辑日程',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 标题输入框 (订阅事件只读)
                    TextField(
                      controller: titleController,
                      style: const TextStyle(fontSize: 16),
                      readOnly: isSubscribed,
                      decoration: InputDecoration(
                        hintText: '标题 (例如: 开会)', 
                        prefixIcon: Icon(Icons.title, size: 20, color: isSubscribed ? Colors.grey[400] : Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 描述输入框
                    TextField(
                      controller: descController,
                      style: const TextStyle(fontSize: 16),
                      decoration: const InputDecoration(
                        hintText: '备注 (可选)',
                        prefixIcon: Icon(Icons.notes, size: 20, color: Colors.grey),
                      ),
                      maxLines: 3,
                      minLines: 1,
                    ),
                    const SizedBox(height: 20),
                    
                    // 颜色选择器 (自建事件才显示)
                    if (!isSubscribed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('选择标签颜色', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12.0,
                              children: _availableColors.map((color) {
                                return GestureDetector(
                                  onTap: () {
                                    setDialogState(() {
                                      selectedColor = color;
                                    });
                                  },
                                  child: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: color,
                                    child: selectedColor == color
                                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                                        : null,
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    
                    // 时间/全天选项
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile.adaptive(
                            title: const Text('全天', style: TextStyle(fontSize: 16)),
                            value: isAllDay,
                            activeColor: const Color(0xFF5E5CE6),
                            onChanged: isSubscribed ? null : (val) => setDialogState(() => isAllDay = val),
                          ),
                          if (!isAllDay) ...[
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            ListTile(
                              title: const Text('时间', style: TextStyle(fontSize: 16)),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  DateFormat('MM-dd HH:mm').format(selectedDateTime),
                                  style: TextStyle(
                                    color: isSubscribed ? Colors.grey : const Color(0xFF5E5CE6), 
                                    fontWeight: FontWeight.bold
                                  ),
                                ),
                              ),
                              onTap: isSubscribed ? null : () async {
                                final TimeOfDay? time = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.fromDateTime(selectedDateTime),
                                );
                                if (mounted && time != null) { // 修复：在异步操作后，检查 State 是否 mounted
                                  setDialogState(() {
                                    selectedDateTime = DateTime(
                                      selectedDateTime.year,
                                      selectedDateTime.month,
                                      selectedDateTime.day,
                                      time.hour,
                                      time.minute,
                                    );
                                  });
                                }
                              },
                            ),
                          ]
                        ],
                      ),
                    ),
                    if (isSubscribed)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text("⚠️ 订阅事件的时间和全天状态不可修改", style: TextStyle(fontSize: 12, color: Colors.redAccent)),
                      ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(foregroundColor: Colors.grey),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (titleController.text.isEmpty) return;
                          final provider = Provider.of<EventProvider>(context, listen: false);
                          
                          // 订阅事件：保持原有的时间和订阅状态不变
                          DateTime finalDate = isSubscribed ? eventToEdit!.date : selectedDateTime;
                          bool finalIsAllDay = isSubscribed ? eventToEdit!.isAllDay : isAllDay;
                          
                          final newEvent = Event(
                            id: eventToEdit?.id ?? const Uuid().v4(),
                            title: titleController.text,
                            description: descController.text,
                            date: finalDate,
                            isAllDay: finalIsAllDay,
                            isSubscribed: isSubscribed,
                            colorValue: isSubscribed ? eventToEdit!.colorValue : selectedColor.value, // 保存选中的颜色值
                          );

                          if (eventToEdit == null) {
                            provider.addEvent(newEvent);
                          } else {
                            provider.updateEvent(eventToEdit, newEvent);
                          }
                          Navigator.pop(context);
                        },
                        child: const Text('保存'),
                      ),
                    ),
                  ],
                )
              ],
            );
          },
        );
      },
    );
  }

  // ==========================
  // 订阅管理弹窗 (Modal Bottom Sheet) - 已修正优先显示备注
  // ==========================
  void _showSubscriptionManager(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final eventProvider = Provider.of<EventProvider>(context);
        
        return FutureBuilder<List<SubscriptionSource>>(
          future: eventProvider.getSubscriptions(),
          builder: (context, snapshot) {
            final List<SubscriptionSource> subscriptions = snapshot.data ?? [];
            
            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '订阅源管理',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Expanded(child: Center(child: CircularProgressIndicator())),
                  if (subscriptions.isEmpty && snapshot.connectionState != ConnectionState.waiting)
                    const Expanded(child: Center(child: Text("当前没有订阅任何日历源"))),
                  
                  Expanded(
                    child: ListView.builder(
                      itemCount: subscriptions.length,
                      itemBuilder: (context, index) {
                        final sub = subscriptions[index];
                        return ListTile(
                          // 核心修正：Title 显示备注名称，Subtitle 显示 URL
                          title: Text(sub.name, style: const TextStyle(fontWeight: FontWeight.w600)), 
                          subtitle: Text(sub.url, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                          leading: Icon(
                            Icons.link,
                            color: Colors.blue.shade600,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('确认删除?'),
                                  content: Text('删除订阅源 "${sub.name}" 将移除所有相关日程。'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除', style: TextStyle(color: Colors.red))),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                if (mounted) Navigator.pop(context); 
                                await eventProvider.deleteSubscriptionSource(context, sub.url);
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ==========================
  // 网络订阅弹窗 (增加备注输入框)
  // ==========================
  void _showSubscribeDialog(BuildContext context) {
    final urlController = TextEditingController();
    final nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Center(child: Text("订阅日历", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 订阅 URL
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                hintText: "输入 .ics 链接 (必填)",
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 12),
            // 订阅备注
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                hintText: "输入备注名称 (如: 公司假期)",
                prefixIcon: Icon(Icons.label_important_outline),
              ),
            ),
            const SizedBox(height: 8),
            const Text("提示：您可以搜索 '中国节假日 ics' 获取链接", style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("取消", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              if (urlController.text.isNotEmpty) {
                // 异步操作前的同步操作
                Navigator.pop(context);
                // 传入备注名称
                Provider.of<EventProvider>(context, listen: false)
                    .subscribeToCalendar(context, urlController.text, sourceName: nameController.text);
              }
            },
            child: const Text("订阅"),
          ),
        ],
      ),
    );
  }


@override
Widget build(BuildContext context) {
    final eventProvider = Provider.of<EventProvider>(context);
    final selectedEvents = eventProvider.getEventsForDay(_selectedDay ?? DateTime.now());

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        title: const Text('我的日程'),
        actions: [
          // 管理订阅按钮
          IconButton(
            icon: const Icon(Icons.settings_suggest_rounded, color: Colors.black),
            onPressed: () => _showSubscriptionManager(context),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded, color: Colors.black),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              if (value == 'export') eventProvider.exportEvents(context);
              if (value == 'import') eventProvider.importEvents(context);
              if (value == 'subscribe') _showSubscribeDialog(context);
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(value: 'export', child: Row(children: [Icon(Icons.ios_share, size: 20), SizedBox(width: 12), Text('导出备份')])),
              const PopupMenuItem<String>(value: 'import', child: Row(children: [Icon(Icons.file_download_outlined, size: 20), SizedBox(width: 12), Text('导入恢复')])),
              const PopupMenuItem<String>(value: 'subscribe', child: Row(children: [Icon(Icons.rss_feed, size: 20), SizedBox(width: 12), Text('网络订阅')])),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. 日历卡片区域 (动画和手势逻辑不变)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizeTransition(
                    sizeFactor: _animation,
                    child: TableCalendar(
                      locale: 'zh_CN',
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      calendarFormat: _calendarFormat,
                      eventLoader: (day) => eventProvider.getEventsForDay(day),
                      
                      headerStyle: const HeaderStyle(
                        titleCentered: true,
                        formatButtonVisible: false,
                        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        leftChevronIcon: Icon(Icons.chevron_left, color: Color(0xFF5E5CE6)),
                        rightChevronIcon: Icon(Icons.chevron_right, color: Color(0xFF5E5CE6)),
                      ),
                      calendarStyle: const CalendarStyle(
                        outsideDaysVisible: false,
                      ),
                      
                      rowHeight: 56, // 修复溢出问题
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (context, day, focusedDay) => _buildCalendarCell(day),
                        selectedBuilder: (context, day, focusedDay) => _buildCalendarCell(day, isSelected: true),
                        todayBuilder: (context, day, focusedDay) => _buildCalendarCell(day, isToday: true),
                      ),
                      
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      onDaySelected: (selectedDay, focusedDay) {
                        if (!isSameDay(_selectedDay, selectedDay)) {
                          setState(() {
                            _selectedDay = selectedDay;
                            _focusedDay = focusedDay;
                          });
                        }
                      },
                      onFormatChanged: (format) {
                        if (_calendarFormat != format) setState(() => _calendarFormat = format);
                      },
                      onPageChanged: (focusedDay) => _focusedDay = focusedDay,
                    ),
                  ),
                  
                  GestureDetector(
                    onTap: _toggleCalendarFormat,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: Colors.grey.shade100, width: 1)),
                      ),
                      child: Center(
                        child: RotationTransition(
                          turns: Tween(begin: 0.0, end: 0.5).animate(_animationController),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded, 
                            color: Colors.grey,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // 2. 列表标题
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              children: [
                Text(
                  "日程清单",
                  style: TextStyle(
                    fontSize: 20, 
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const Spacer(),
                Text(
                  "${selectedEvents.length} 个事项",
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 3. 日程列表区域
          Expanded(
            child: selectedEvents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_note_rounded, size: 60, color: Colors.grey[300]),
                      const SizedBox(height: 10),
                      Text("今天没有安排", style: TextStyle(color: Colors.grey[400])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount: selectedEvents.length,
                  itemBuilder: (context, index) {
                    final event = selectedEvents[index];
                    
                    final Color tagColor = event.colorValue != null 
                                            ? Color(event.colorValue!) 
                                            : (event.isSubscribed ? Colors.blue.shade600 : const Color(0xFF5E5CE6));
                    
                    final Color lightTagColor = tagColor.withOpacity(0.1);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        onTap: () => _showAddEventDialog(eventToEdit: event),
                        
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: lightTagColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            event.isAllDay ? Icons.calendar_today_rounded : Icons.access_time_filled_rounded,
                            color: tagColor,
                            size: 20,
                          ),
                        ),
                        
                        title: Row(
                          children: [
                            Text(
                              event.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            if (event.isSubscribed) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '订阅',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                              ),
                            ]
                          ],
                        ),
                        
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              event.isAllDay 
                                ? "全天" 
                                : DateFormat('HH:mm').format(event.date),
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                            if (event.description != null && event.description!.isNotEmpty)
                              Text(
                                event.description!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.grey[400], fontSize: 12),
                              ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey),
                          onPressed: () {
                            eventProvider.deleteEvent(event);
                          },
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEventDialog(),
        backgroundColor: const Color(0xFF5E5CE6),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
}
}
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'pages/calendar_page.dart'; 
import 'providers/event_provider.dart';
import 'services/notification_service.dart'; 

// 1. 修改这里：添加 async
void main() async {
  // 2. 修改这里：确保 Flutter 绑定初始化，这是使用异步代码的前提
  WidgetsFlutterBinding.ensureInitialized(); 

  // 等待日期格式化初始化
  await initializeDateFormatting();
  
  // 3. 修改这里：初始化通知服务
  await NotificationService().init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => EventProvider()),
      ],
      child: const CalendarApp(),
    ),
  );
}

class CalendarApp extends StatelessWidget {
  const CalendarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calendar App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const CalendarPage(),
    );
  }
}
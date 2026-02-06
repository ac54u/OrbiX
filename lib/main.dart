import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:quick_actions/quick_actions.dart';

// 引入您刚才发的那个配色文件
import 'core/constants.dart'; 
import 'services/server_manager.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/main_tab_scaffold.dart';
import 'screens/search/search_screen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 移除强制的 Style 设置，交给后面动态判断
  // SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

  final hasServers = await ServerManager.hasServers();
  await _initNotifications();

  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://db35293e486355c70e7f20f377f9dc31@o4510735505358848.ingest.us.sentry.io/4510735511715840';
      options.tracesSampleRate = 1.0;
      options.debug = false;
    },
    appRunner: () => runApp(MyApp(startOnboarding: !hasServers)),
  );
}

Future<void> _initNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings initializationSettingsDarwin =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsDarwin,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

class MyApp extends StatefulWidget {
  final bool startOnboarding;
  const MyApp({super.key, required this.startOnboarding});

  @override
  State<MyApp> createState() => _MyAppState();
}

// ✅ 混入 WidgetsBindingObserver 以监听系统外观变化
class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final QuickActions quickActions = const QuickActions();

  @override
  void initState() {
    super.initState();
    // 注册监听器
    WidgetsBinding.instance.addObserver(this);
    
    // 初始化时先判断一次当前系统亮度，更新您的 themeNotifier
    // 注意：addPostFrameCallback 确保 context 可用
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateThemeFromSystem();
    });

    _setupQuickActions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ✅ 当系统亮度发生变化时（如控制中心切换深色模式），自动同步
  @override
  void didChangePlatformBrightness() {
    _updateThemeFromSystem();
  }

  // 同步逻辑：系统变黑 -> themeNotifier 变 true -> 您的常量文件返回黑色
  void _updateThemeFromSystem() {
    final brightness = View.of(context).platformDispatcher.platformBrightness;
    final isDark = brightness == Brightness.dark;
    // 更新全局状态
    themeNotifier.value = isDark;
  }

  void _setupQuickActions() {
    quickActions.initialize((String shortcutType) {
      if (shortcutType == 'action_search') {
        navigatorKey.currentState?.push(
          CupertinoPageRoute(
            builder: (context) => const SearchScreen(autoPaste: true),
          ),
        );
      }
    });

    quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(
        type: 'action_search',
        localizedTitle: '一键搜索',
        icon: 'ic_search',
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 使用 ValueListenableBuilder 监听您的 themeNotifier
    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDark, child) {
        return CupertinoApp(
          navigatorKey: navigatorKey,
          title: 'Orbix',
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('zh', 'CN'),
            Locale('en', 'US'),
          ],
          // ✅ 这里的 Theme 会根据您的 constants.dart 动态变化
          theme: CupertinoThemeData(
            brightness: isDark ? Brightness.dark : Brightness.light,
            primaryColor: kPrimaryColor, // 您的蓝色
            
            // 背景色：使用您定义的常量
            scaffoldBackgroundColor: isDark ? kBgColorDark : kBgColorLight,
            
            // 导航栏/卡片背景：使用您定义的常量
            barBackgroundColor: isDark ? kCardColorDark : const Color(0xCCF9F9F9),
            
            textTheme: CupertinoTextThemeData(
              textStyle: GoogleFonts.outfit(
                color: isDark ? Colors.white : Colors.black,
              ),
              navTitleTextStyle: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
              navLargeTitleTextStyle: GoogleFonts.outfit(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          home: widget.startOnboarding
              ? const OnboardingScreen()
              : const MainTabScaffold(),
        );
      },
    );
  }
}
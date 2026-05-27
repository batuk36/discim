import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';
import 'core/providers/locale_provider.dart';
import 'features/auth/providers/auth_provider.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await initializeDateFormatting('tr', null);
  runApp(const DiscimApp());
  // Notification izni ve init, uygulama başladıktan sonra arka planda yapılır.
  // Böylece iOS'ta uygulama açılmadan önce izin dialogu gösterilmez.
  unawaited(NotificationService.init());
}

class DiscimApp extends StatelessWidget {
  const DiscimApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, localeProvider, _) {
          final router = createRouter(context);
          return MaterialApp.router(
            title: 'Dişçim',
            theme: AppTheme.light,
            routerConfig: router,
            debugShowCheckedModeBanner: false,
            locale: localeProvider.locale,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('tr'),
              Locale('en'),
            ],
          );
        },
      ),
    );
  }
}

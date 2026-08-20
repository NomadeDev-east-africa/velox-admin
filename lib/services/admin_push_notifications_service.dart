import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../constants.dart';
import 'notification_sound.dart';

/// Enregistre le token FCM web de l'admin connecté et expose les messages
/// reçus au premier plan (onglet ouvert). Le cas arrière-plan/onglet fermé
/// est géré nativement par web/firebase-messaging-sw.js.
class AdminPushNotificationsService {
  AdminPushNotificationsService._();
  static final AdminPushNotificationsService instance =
      AdminPushNotificationsService._();

  final _foregroundMessagesController =
      StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get foregroundMessages =>
      _foregroundMessagesController.stream;

  StreamSubscription<String>? _tokenRefreshSub;
  bool _initialized = false;

  Future<void> initialize() async {
    if (!kIsWeb || _initialized) return;
    _initialized = true;

    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('⚠️ Permission notifications refusée');
        return;
      }

      final token = await _getTokenWithRetry(messaging);
      if (token != null) await _registerToken(token);

      _tokenRefreshSub = messaging.onTokenRefresh.listen(_registerToken);

      FirebaseMessaging.onMessage.listen((message) {
        playNotificationSound();
        _foregroundMessagesController.add(message);
      });
    } catch (e) {
      debugPrint('⚠️ Erreur initialisation notifications push admin: $e');
    }
  }

  // Sur web, le service worker (firebase-messaging-sw.js) n'est parfois pas encore
  // "activated" au tout premier chargement de page — getToken() échoue alors avec
  // MissingPluginException/PushManager subscribe error. Connu côté FlutterFire
  // (firebase/flutterfire#11798) : un simple retry après un court délai suffit,
  // le SW étant actif quelques centaines de ms plus tard.
  Future<String?> _getTokenWithRetry(FirebaseMessaging messaging) async {
    const delays = [Duration(seconds: 1), Duration(seconds: 2), Duration(seconds: 4)];
    for (var attempt = 0; ; attempt++) {
      try {
        return await messaging.getToken(vapidKey: webPushVapidKey);
      } catch (e) {
        if (attempt >= delays.length) {
          debugPrint('⚠️ getToken a échoué après ${delays.length} tentatives: $e');
          return null;
        }
        debugPrint('⚠️ getToken tentative ${attempt + 1} échouée, retry: $e');
        await Future.delayed(delays[attempt]);
      }
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      await FirebaseFunctions.instance
          .httpsCallable('registerAdminFcmToken')
          .call({'token': token});
    } catch (e) {
      debugPrint('⚠️ Erreur enregistrement token FCM admin: $e');
    }
  }

  void dispose() {
    _tokenRefreshSub?.cancel();
    _foregroundMessagesController.close();
  }
}

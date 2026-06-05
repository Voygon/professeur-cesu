import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../database/app_database.dart';

const _actionValider = 'valider_cours';

// Top-level function requise par flutter_local_notifications pour le handler
// d'actions en background (showsUserInterface:true amène l'app au premier plan
// et déclenche onDidReceiveNotificationResponse — ce handler reste vide).
@pragma('vm:entry-point')
void _notifBackgroundHandler(NotificationResponse response) {}

class NotificationService {
  NotificationService._();

  static const _cleRappel = 'rappel_minutes_avant';
  static const _rappelDefaut = 30;
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialise = false;

  // Tap sur le corps de la notification → ouvrir la fiche du cours
  static final _tapController = StreamController<int>.broadcast();
  // Tap sur le bouton "Valider" → valider directement
  static final _validerController = StreamController<int>.broadcast();

  static Stream<int> get tapStream => _tapController.stream;
  static Stream<int> get validerStream => _validerController.stream;

  // ── Initialisation ────────────────────────────────────────────────────────

  static Future<void> init() async {
    if (_initialise) return;

    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(DateTime.now().timeZoneName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Europe/Paris'));
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    final ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [
        DarwinNotificationCategory(
          'cours_fin_category',
          actions: [
            DarwinNotificationAction.plain(
              _actionValider,
              'Valider le cours',
              options: {DarwinNotificationActionOption.foreground},
            ),
          ],
        ),
      ],
    );

    await _plugin.initialize(
      InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _handleResponse,
      onDidReceiveBackgroundNotificationResponse: _notifBackgroundHandler,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialise = true;
  }

  static void _handleResponse(NotificationResponse response) {
    final coursId = _parseCoursId(response.payload);
    if (coursId == null) return;
    if (response.actionId == _actionValider) {
      _validerController.add(coursId);
    } else {
      _tapController.add(coursId);
    }
  }

  static int? _parseCoursId(String? payload) {
    if (payload == null) return null;
    final parts = payload.split(':');
    if (parts.length == 2 && parts[0] == 'coursId') {
      return int.tryParse(parts[1]);
    }
    return int.tryParse(payload);
  }

  /// À appeler une fois les streams écoutés (après initState) pour gérer
  /// le cas "app lancée depuis l'état tué via un tap sur notification".
  static Future<void> checkLaunchNotification() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return;
    final response = details?.notificationResponse;
    if (response != null) _handleResponse(response);
  }

  // ── Préférences ───────────────────────────────────────────────────────────

  static Future<int> getRappelMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_cleRappel) ?? _rappelDefaut;
  }

  static Future<void> setRappelMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_cleRappel, minutes);
  }

  // ── Planification ─────────────────────────────────────────────────────────

  /// Planifie deux notifications pour un cours :
  ///  • rappel N min avant (ID = coursId * 2)
  ///  • fin de cours avec bouton Valider (ID = coursId * 2 + 1)
  static Future<void> planifierNotificationCours(
    Cour cours,
    Eleve eleve, {
    int? rappelMinutes,
  }) async {
    final minutes = rappelMinutes ?? await getRappelMinutes();
    final duree = cours.dureeReelle ?? eleve.dureeCours ?? 60;
    final payload = 'coursId:${cours.coursId}';
    final heure =
        '${cours.datePrevue.hour.toString().padLeft(2, '0')}:${cours.datePrevue.minute.toString().padLeft(2, '0')}';

    // ── Rappel avant le cours ────────────────────────────────────────────
    final heureNotif = cours.datePrevue.subtract(Duration(minutes: minutes));
    if (!heureNotif.isBefore(DateTime.now())) {
      await _plugin.zonedSchedule(
        cours.coursId * 2,
        'Cours dans $minutes min',
        '${eleve.prenom} ${eleve.nom} — $heure ($duree min)',
        tz.TZDateTime.from(heureNotif, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'cours_rappel',
            'Rappels de cours',
            channelDescription: 'Rappels avant chaque cours',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    }

    // ── Fin de cours ─────────────────────────────────────────────────────
    final heureFin = cours.datePrevue.add(Duration(minutes: duree));
    if (!heureFin.isBefore(DateTime.now())) {
      await _plugin.zonedSchedule(
        cours.coursId * 2 + 1,
        '${eleve.prenom} ${eleve.nom}',
        'Cours de $heure ($duree min) — A-t-il été effectué ?',
        tz.TZDateTime.from(heureFin, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'cours_fin',
            'Fin de cours',
            channelDescription: 'Notification à la fin de chaque cours',
            importance: Importance.high,
            priority: Priority.high,
            actions: const [
              AndroidNotificationAction(
                _actionValider,
                'Valider le cours',
                showsUserInterface: true,
              ),
            ],
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            categoryIdentifier: 'cours_fin_category',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    }
  }

  static Future<void> annulerNotificationCours(int coursId) async {
    await _plugin.cancel(coursId * 2);
    await _plugin.cancel(coursId * 2 + 1);
  }

  static Future<void> annulerToutesNotifications() async {
    await _plugin.cancelAll();
  }

  static Future<void> replanifierTout(
    List<Cour> cours,
    Map<int, Eleve> elevesParId, {
    int? rappelMinutes,
  }) async {
    await annulerToutesNotifications();
    final minutes = rappelMinutes ?? await getRappelMinutes();
    for (final c in cours) {
      if (c.statut == 'annule') continue;
      final eleve = elevesParId[c.elevesId];
      if (eleve == null) continue;
      await planifierNotificationCours(c, eleve, rappelMinutes: minutes);
    }
  }
}

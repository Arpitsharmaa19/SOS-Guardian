// Flutter web plugin registrant file.
//
// Generated file. Do not edit.
//

// @dart = 2.13
// ignore_for_file: type=lint

import 'package:cloud_firestore_web/cloud_firestore_web.dart';
import 'package:firebase_auth_web/firebase_auth_web.dart';
import 'package:firebase_core_web/firebase_core_web.dart';
import 'package:firebase_messaging_web/firebase_messaging_web.dart';
import 'package:flutter_native_splash/flutter_native_splash_web.dart';
import 'package:flutter_sms/flutter_sms_web.dart';
import 'package:geolocator_web/geolocator_web.dart';
import 'package:location_web/location_web.dart';
import 'package:permission_handler_html/permission_handler_html.dart';
import 'package:speech_to_text/speech_to_text_web.dart';
import 'package:url_launcher_web/url_launcher_web.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

void registerPlugins([final Registrar? pluginRegistrar]) {
  final Registrar registrar = pluginRegistrar ?? webPluginRegistrar;
  FirebaseFirestoreWeb.registerWith(registrar);
  FirebaseAuthWeb.registerWith(registrar);
  FirebaseCoreWeb.registerWith(registrar);
  FirebaseMessagingWeb.registerWith(registrar);
  FlutterNativeSplashWeb.registerWith(registrar);
  FlutterSmsPlugin.registerWith(registrar);
  GeolocatorPlugin.registerWith(registrar);
  LocationWebPlugin.registerWith(registrar);
  WebPermissionHandler.registerWith(registrar);
  SpeechToTextPlugin.registerWith(registrar);
  UrlLauncherPlugin.registerWith(registrar);
  registrar.registerMessageHandler();
}

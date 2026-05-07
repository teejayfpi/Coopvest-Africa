// File generated from google-services.json — do not edit by hand.
// ignore_for_file: type=lint

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows — '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux — '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBqTLdRdvzUrloF09wNbvc2AQV5OvShcuw',
    appId: '1:1040576298736:android:9ab079fef03f2c19d28c35',
    messagingSenderId: '1040576298736',
    projectId: 'coopvest-africa-46a86',
    databaseURL: 'https://coopvest-africa-46a86-default-rtdb.firebaseio.com',
    storageBucket: 'coopvest-africa-46a86.firebasestorage.app',
    androidClientId: '1040576298736-991ja94slls4f6csarfheerlkg7bfpon.apps.googleusercontent.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBqTLdRdvzUrloF09wNbvc2AQV5OvShcuw',
    appId: '1:1040576298736:ios:9ab079fef03f2c19d28c35',
    messagingSenderId: '1040576298736',
    projectId: 'coopvest-africa-46a86',
    databaseURL: 'https://coopvest-africa-46a86-default-rtdb.firebaseio.com',
    storageBucket: 'coopvest-africa-46a86.firebasestorage.app',
    iosBundleId: 'com.coopvestafrica.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBqTLdRdvzUrloF09wNbvc2AQV5OvShcuw',
    appId: '1:1040576298736:ios:9ab079fef03f2c19d28c35',
    messagingSenderId: '1040576298736',
    projectId: 'coopvest-africa-46a86',
    databaseURL: 'https://coopvest-africa-46a86-default-rtdb.firebaseio.com',
    storageBucket: 'coopvest-africa-46a86.firebasestorage.app',
    iosBundleId: 'com.coopvestafrica.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBqTLdRdvzUrloF09wNbvc2AQV5OvShcuw',
    appId: '1:1040576298736:web:9ab079fef03f2c19d28c35',
    messagingSenderId: '1040576298736',
    projectId: 'coopvest-africa-46a86',
    authDomain: 'coopvest-africa-46a86.firebaseapp.com',
    databaseURL: 'https://coopvest-africa-46a86-default-rtdb.firebaseio.com',
    storageBucket: 'coopvest-africa-46a86.firebasestorage.app',
  );
}

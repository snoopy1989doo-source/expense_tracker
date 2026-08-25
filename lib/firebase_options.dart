import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDB61ZXb8i_Kz8-BvANRSsqgW5xUcg1bxk',
    authDomain: 'meyou-couple-app.firebaseapp.com',
    projectId: 'meyou-couple-app',
    storageBucket: 'meyou-couple-app.firebasestorage.app',
    messagingSenderId: '1060106366151',
    appId: '1:1060106366151:web:20ba604035e0624d39a2e2',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDB61ZXb8i_Kz8-BvANRSsqgW5xUcg1bxk',
    authDomain: 'meyou-couple-app.firebaseapp.com',
    projectId: 'meyou-couple-app',
    storageBucket: 'meyou-couple-app.firebasestorage.app',
    messagingSenderId: '1060106366151',
    appId: '1:1060106366151:web:20ba604035e0624d39a2e2',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDB61ZXb8i_Kz8-BvANRSsqgW5xUcg1bxk',
    authDomain: 'meyou-couple-app.firebaseapp.com',
    projectId: 'meyou-couple-app',
    storageBucket: 'meyou-couple-app.firebasestorage.app',
    messagingSenderId: '1060106366151',
    appId: '1:1060106366151:web:20ba604035e0624d39a2e2',
  );
}

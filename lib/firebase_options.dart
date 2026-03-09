// File generated for Firebase multi-platform support
// Project: gen-lang-client-0051029580

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
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBsvvtxPfMMVkx969vHKmgvLF-9JWLJ6BM',
    authDomain: 'gen-lang-client-0051029580.firebaseapp.com',
    projectId: 'gen-lang-client-0051029580',
    storageBucket: 'gen-lang-client-0051029580.firebasestorage.app',
    messagingSenderId: '502971682448',
    appId: '1:502971682448:web:710016469c5b594f3f1215',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBsvvtxPfMMVkx969vHKmgvLF-9JWLJ6BM',
    appId: '1:872742718515:android:921c89fe5ccc2a7d74e746',
    messagingSenderId: '872742718515',
    projectId: 'gen-lang-client-0051029580',
    storageBucket: 'gen-lang-client-0051029580.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBsvvtxPfMMVkx969vHKmgvLF-9JWLJ6BM',
    appId: '1:872742718515:ios:000000000000000000000000',
    messagingSenderId: '872742718515',
    projectId: 'gen-lang-client-0051029580',
    storageBucket: 'gen-lang-client-0051029580.firebasestorage.app',
    iosClientId: '',
    iosBundleId: 'com.teamply.mobile',
  );
}

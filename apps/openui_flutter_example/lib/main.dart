import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:dartantic_firebase_ai/dartantic_firebase_ai.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:openui_flutter_example/firebase_options.dart';
import 'package:openui_flutter_example/src/shell/app_shell.dart';

/// Web reCAPTCHA Enterprise site key, injected at build time via
/// `--dart-define=RECAPTCHA_ENTERPRISE_SITE_KEY=<key>`. Empty in dev
/// builds; `main` refuses to activate App Check with an empty key (see
/// fail-closed comment below).
const String _recaptchaSiteKey = String.fromEnvironment(
  'RECAPTCHA_ENTERPRISE_SITE_KEY',
);

/// Dartantic agent string registered for the live-chat surface. Mirrors
/// the constant in `DartanticChatService` — kept in lockstep so the
/// factory and the consumer agree.
const String _firebaseVertexAgent = 'firebase-vertex';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (_recaptchaSiteKey.isEmpty) {
      throw StateError(
        'RECAPTCHA_ENTERPRISE_SITE_KEY is empty. Refusing to activate App '
        'Check without a site key — the Live chat surface would otherwise '
        'ship without abuse protection. See README "Live chat setup".',
      );
    }
    await FirebaseAppCheck.instance.activate(
      providerWeb: ReCaptchaEnterpriseProvider(_recaptchaSiteKey),
    );
    Agent.providerFactories[_firebaseVertexAgent] = () =>
        FirebaseAIProvider(backend: FirebaseAIBackend.vertexAI);
  } on Object catch (error, stackTrace) {
    // Firebase or App Check init failed. The Scripts destination of
    // `AppShell` does not depend on either and still works; the Live
    // destination will surface this error if the user navigates to it.
    debugPrint(
      'Live chat unavailable — Firebase/App Check init failed.\n'
      'See apps/openui_flutter_example/README.md "Live chat setup".\n'
      'Error: $error\n$stackTrace',
    );
  }
  runApp(const OpenUIExampleApp());
}

/// Boots the streaming-chat demo.
class OpenUIExampleApp extends StatelessWidget {
  /// Creates the example app.
  const OpenUIExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenUI Flutter',
      theme: ThemeData(useMaterial3: true),
      home: const AppShell(),
    );
  }
}

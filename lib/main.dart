import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:operation_sunrise/app/app_lifecycle.dart';
import 'package:operation_sunrise/audio/audio_controller.dart';
import 'package:operation_sunrise/constants.dart';
import 'package:operation_sunrise/database/local_storage_settings_persistence.dart';
import 'package:operation_sunrise/database/settings_controller.dart';
import 'package:operation_sunrise/firebase_options.dart';
import 'package:operation_sunrise/game_screen.dart';
import 'package:provider/provider.dart';

Future<void> setUpRemoteConfig() async {
  final remoteConfig = FirebaseRemoteConfig.instance;
  await remoteConfig.setConfigSettings(
    RemoteConfigSettings(
      fetchTimeout: const Duration(minutes: 1),
      minimumFetchInterval: const Duration(minutes: 1), //TODO: Change for production
    ),
  );
  await remoteConfig.setDefaults(const {C.minutesBeforeFirstAd: 5});
  remoteConfig.onConfigUpdated.listen((event) async {
    await remoteConfig.activate();
  });
  await remoteConfig.fetchAndActivate();
}

Future<void> main() async {
  // Ensure that all Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  // Activate App Check
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.appAttest,
  );

  await setUpRemoteConfig();

  if (FirebaseAuth.instance.currentUser == null) {
    try {
      print("No user found. Signing in anonymously...");
      await FirebaseAuth.instance.signInAnonymously();
      print("Sign-in successful.");
    } catch (e) {
      print("Error signing in anonymously: $e");
    }
  } else {
    print("Existing user found.");
  }

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final settingsController = SettingsController(
    persistence: LocalStorageSettingsPersistence(),
  );
  await settingsController.loadStateFromPersistence();

  // FIXED: MultiProvider is now at the top level, wrapping the entire app.
  runApp(
    AppLifecycleObserver(
      child: MultiProvider(
        providers: [
          Provider<SettingsController>(
            lazy: false,
            create: (context) => settingsController,
          ),
          ProxyProvider2<SettingsController, ValueNotifier<AppLifecycleState>,
              AudioController>(
            lazy: false,
            create: (context) => AudioController()..initialize(),
            update: (context, settings, lifecycleNotifier, audio) {
              if (audio == null) throw ArgumentError.notNull();
              audio.attachSettings(settings);
              audio.attachLifecycleNotifier(lifecycleNotifier);
              return audio;
            },
            dispose: (context, audio) => audio.dispose(),
          ),
        ],
        child: MyApp(settingsController: settingsController),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final SettingsController settingsController;

  const MyApp({super.key, required this.settingsController});

  @override
  Widget build(BuildContext context) {
    // FIXED: MyApp now only returns MaterialApp. The providers are already above it
    // in the widget tree, making them available to all routes.
    return MaterialApp(
      title: 'Operation Sunrise',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: MyHomePage(title: "Tere"),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('levels')
            .orderBy('levelNumber')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No levels found.'));
          }

          var levelDocs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: levelDocs.length,
            itemBuilder: (context, index) {
              var levelData = levelDocs[index].data() as Map<String, dynamic>;
              final String? videoPath = levelData['path'];

              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(levelData['levelNumber'].toString()),
                  ),
                  title: Text(levelData['name'] ?? 'Unnamed Level'),
                  subtitle: Text(
                    'Difficulty: ${levelData['difficulty'] ?? 'N/A'}',
                  ),
                  trailing: const Icon(Icons.play_circle_outline),
                  onTap: () {
                    if (videoPath != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GameScreen(
                            videoPath: videoPath,
                            levelName: levelData['name'] ?? 'A Level',
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No video available for this level.'),
                        ),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
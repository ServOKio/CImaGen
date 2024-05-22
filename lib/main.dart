import 'dart:io';

import 'package:cimagen/modules/NotificationManager.dart';
import 'package:cimagen/pages/Timeline.dart';
import 'package:cimagen/utils/AppBarController.dart';
import 'package:cimagen/utils/DataModel.dart';
import 'package:cimagen/utils/GitHub.dart';
import 'package:cimagen/utils/ImageManager.dart';
import 'package:cimagen/utils/NavigationService.dart';
import 'package:cimagen/utils/SQLite.dart';
import 'package:cimagen/utils/SaveManager.dart';
import 'package:cimagen/utils/ThemeManager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:feedback/feedback.dart';
import 'package:cimagen/Utils.dart';
import 'package:cimagen/pages/Comparison.dart';
import 'package:cimagen/pages/Gallery.dart';
import 'package:cimagen/pages/Home.dart';
import 'package:cimagen/pages/Settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_theme/system_theme.dart';
import 'package:window_manager/window_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'components/AppBar.dart';
import 'components/NotesSection.dart';
import 'l10n/all_locales.dart';

GitHub? githubAPI;
AppBarController? appBarController;
NotificationManager? notificationManager;
SharedPreferences? prefs;

Future<void> main() async {
  bool debug = false;
  if(debug) {
    runApp(Test());
  } else {
    WidgetsFlutterBinding.ensureInitialized();
    await SystemTheme.accentColor.load();
    if (Platform.isWindows) {
      await windowManager.ensureInitialized();
      WindowManager.instance.setMinimumSize(const Size(450, 450));
    }
    runApp(MyApp());
  }
}

class Test extends StatelessWidget {
  const Test({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: const Center(child: Text("Hello World!!!")),
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.call),
              label: 'Calls',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.camera),
              label: 'Camera',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat),
              label: 'Chats',
            ),
          ],
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {

  MyApp({super.key}) {
    initAsync();
    appBarController = AppBarController();
    notificationManager = NotificationManager();
    notificationManager?.init();
  }

  Future<void> initAsync() async {
    prefs = await SharedPreferences.getInstance();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => DataModel()),
        ChangeNotifierProvider(create: (_) => ConfigManager()),
        ChangeNotifierProvider(create: (_) => SQLite()),
        ChangeNotifierProvider(create: (_) => ImageManager()),
        ChangeNotifierProvider(create: (_) => ThemeManager()),
        ChangeNotifierProvider(create: (_) => SaveManager()),
      ],
      child: BetterFeedback(
          theme: FeedbackThemeData(
            background: Colors.black,
            bottomSheetDescriptionStyle: const TextStyle(color: Colors.white),
            bottomSheetTextInputStyle: const TextStyle(color: Colors.white),
            feedbackSheetColor: Colors.grey[900]!,
            drawColors: [
              Colors.red,
              Colors.green,
              Colors.blue,
              Colors.yellow,
            ],
          ),
          child: WTF()
      )
    );
  }
}

class WTF extends StatelessWidget{
  const WTF({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeManager>(context);
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AllLocale.all,
      locale: Provider.of<LocaleProvider>(context).locale,

      navigatorKey: NavigationService.navigatorKey,
      debugShowCheckedModeBanner: true,
      theme: theme.getTheme,
      darkTheme: theme.getTheme,
      themeMode: theme.isDark ? ThemeMode.dark : ThemeMode.light,
      home: const Main()
    );
  }

}

class Main extends StatefulWidget {
  const Main({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<Main> with TickerProviderStateMixin{
  late PageController _pageViewController;
  int _currentPageIndex = 0; // 3
  bool permissionRequired = false;

  bool loaded = false;
  bool hasError = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _pageViewController = PageController(
      initialPage: _currentPageIndex
    );
    initMe();
  }

  Future<void> initMe() async {
    githubAPI = GitHub();
    if(Platform.isAndroid){
      if (await Permission.storage.request().isGranted) {
        if (await Permission.manageExternalStorage.request().isGranted) {
          next();
        } else if (await Permission.manageExternalStorage.request().isPermanentlyDenied) {
          await openAppSettings();
        } else if (await Permission.manageExternalStorage.request().isDenied) {
          setState(() {
            permissionRequired = true;
          });
        }
      } else if (await Permission.storage.request().isPermanentlyDenied) {
        await openAppSettings();
      } else if (await Permission.storage.request().isDenied) {
        setState(() {
          permissionRequired = true;
        });
      }
    } else {
      next();
    }
  }

  void next(){
    context.read<ConfigManager>().init().then((v){
      context.read<SQLite>().init().then((v){
        context.read<ImageManager>().init(context);
        context.read<SaveManager>().init(context);
        setState(() {
          loaded = true;
        });
      }).catchError((e){
        if (kDebugMode) print(e);
        error = 'Database loading error\n$e';
        setState(() {
          hasError = true;
        });
      });
    }).catchError((e){
      if (kDebugMode) print(e);
      error = 'The configuration cannot be loaded';
      setState(() {
        hasError = true;
      });
    });

    context.read<DataModel>().jumpToTab = _updateCurrentPageIndex;
  }

  @override
  void dispose() {
    super.dispose();
    _pageViewController.dispose();
  }

  void _showModalBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(30),
          )
      ),
      builder: (context) => const NotesSection(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeManager>(context);

    return Scaffold(
      appBar: CAppBar(),
      body: PageView(
        physics: const NeverScrollableScrollPhysics(),
        controller: _pageViewController,
        children: <Widget>[
          loaded ? const Home() : LoadingState(loaded: loaded, errorMessage: error),
          loaded ? const Gallery() : LoadingState(loaded: loaded, errorMessage: error),
          loaded ? const Timeline() : LoadingState(loaded: loaded, errorMessage: error),
          loaded ? const Comparison() : LoadingState(loaded: loaded, errorMessage: error),
          // loaded ? P404() : LoadingState(loaded: loaded, errorMessage: error),
          // loaded ? P404() : LoadingState(loaded: loaded, errorMessage: error),
          const Settings()
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed:(){
          _showModalBottomSheet(context);
          //theme.setTheme(theme.getTheme==lightTheme?darkTheme:lightTheme);
        },
        tooltip: 'Notes',
        child: const Icon(Icons.note),
      ),
      bottomNavigationBar: NavigationBar(
        height: 70,
        backgroundColor: Theme.of(context).colorScheme.background,
        indicatorColor: Theme.of(context).colorScheme.primary.withOpacity(0.5),
        surfaceTintColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        selectedIndex: _currentPageIndex,
        onDestinationSelected: (int index) {
          _updateCurrentPageIndex(index);
        },
        destinations: const <Widget>[
          NavigationDestination(
            icon: Icon(Icons.inbox),
            selectedIcon: Icon(Icons.all_inbox),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_mosaic_outlined),
            selectedIcon: Icon(Icons.auto_awesome_mosaic),
            label: 'Gallery',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_tree_outlined),
            selectedIcon: Icon(Icons.account_tree_sharp),
            label: 'Render History',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_to_photos_outlined),
            selectedIcon: Icon(Icons.add_to_photos),
            label: 'Comparison',
          ),
          // NavigationDestination(
          //   icon: Icon(Icons.border_all_sharp),
          //   label: 'Grid rebuild',
          // ),
          // NavigationDestination(
          //   icon: Icon(Icons.amp_stories),
          //   label: 'Maybe',
          // ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  void _updateCurrentPageIndex(int index) {
    setState(() {
      _currentPageIndex = index;
    });
    _pageViewController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }
}

class LoadingState extends StatelessWidget{
  bool loaded;
  String? errorMessage;
  LoadingState({super.key, required this.loaded, this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return Center(
        child: Column(
          children: [
            const Icon(Icons.error),
            const Gap(4),
            const Text('Oops, there seems to be a error'),
            Text(errorMessage ?? 'Error wtf')
          ],
        )
    );
  }
}
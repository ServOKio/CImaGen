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
import 'package:cimagen/pages/P404.dart';
import 'package:cimagen/pages/Settings.dart';
import 'package:window_manager/window_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'components/AppBar.dart';
import 'components/NotesSection.dart';
import 'l10n/all_locales.dart';

GitHub? githubAPI;
AppBarController? appBarController;
NotificationManager? notificationManager;

Future<void> main() async {
  bool debug = false;
  if(debug) {
    runApp(Test());
  } else {
    WidgetsFlutterBinding.ensureInitialized();
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
    appBarController = AppBarController();
    notificationManager = NotificationManager();
    notificationManager?.init();
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
        ChangeNotifierProvider(create: (_) => ThemeManager(darkTheme)),
        ChangeNotifierProvider(create: (_) => SaveManager()),
      ],
      child: const BetterFeedback(child: WTF())
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
      debugShowCheckedModeBanner: false,
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
  late TabController _tabController;
  int _currentPageIndex = 3;
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
    _tabController = TabController(
        length: 7,
        initialIndex: _currentPageIndex,
        vsync: this
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
    _tabController.dispose();
  }

  void _showModalBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
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
      drawer: Drawer(
        // Add a ListView to the drawer. This ensures the user can scroll
        // through the options in the drawer if there isn't enough vertical
        // space to fit everything.
        child: ListView(
          // Important: Remove any padding from the ListView.
          padding: EdgeInsets.zero,
          children: const [
            Text('fdf')
          ],
        ),
      ),
      endDrawer: Theme(
          data: Theme.of(context).copyWith(canvasColor: Colors.transparent),
          child: const Drawer(
              child: Stack(
                  children: [
                    Column(
                        children: <Widget>[
                          Center(child: Text('gdfg', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600))),
                          Padding(padding: EdgeInsets.all(7),child: Column(children: [
                            Text('All content posted is responsibility of its respective poster and neither the site nor its staff shall be held responsible or liable in any way shape or form.', style: TextStyle(fontSize: 10)),
                            Text('Please be aware that this kind of fetish artwork is NOT copyrightable in the hosting country and there for its copyright may not be upheld.', style: TextStyle(fontSize: 10)),
                            Text('We are NOT obligated to remove content under the Digital Millennium Copyright Act.', style: TextStyle(fontSize: 10))
                          ])),
                          Padding(padding: EdgeInsets.only(left: 7, right: 7, bottom: 7), child: Text('Contact us by by phone toll-free! 1-844-FOX-BUTT (369-2888)', style: TextStyle(fontSize: 10)))
                        ]
                    )
                  ]

              )
          )
      ),
      appBar: CAppBar(),
      body: PageView(
        physics: Platform.isWindows ? const NeverScrollableScrollPhysics() : null,
        controller: _pageViewController,
        onPageChanged: _handlePageViewChanged,
        children: <Widget>[
          loaded ? const Home() : LoadingState(loaded: loaded, errorMessage: error),
          loaded ? const Gallery() : LoadingState(loaded: loaded, errorMessage: error),
          loaded ? const Timeline() : LoadingState(loaded: loaded, errorMessage: error),
          loaded ? const Comparison() : LoadingState(loaded: loaded, errorMessage: error),
          loaded ? P404() : LoadingState(loaded: loaded, errorMessage: error),
          loaded ? P404() : LoadingState(loaded: loaded, errorMessage: error),
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
          setState(() {
            _currentPageIndex = index;
          });
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
          NavigationDestination(
            icon: Icon(Icons.border_all_sharp),
            label: 'Grid rebuild',
          ),
          NavigationDestination(
            icon: Icon(Icons.amp_stories),
            label: 'Maybe',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  void _updateCurrentPageIndex(int index) {
    _tabController.index = index;
    _pageViewController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _handlePageViewChanged(int currentPageIndex) {
    // if (!_isOnDesktopAndWeb) {
    //   return;
    // }
    _tabController.index = currentPageIndex;
  }

  bool get _isOnDesktopAndWeb {
    if (kIsWeb) {
      return true;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return true;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return false;
    }
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
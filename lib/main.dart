import 'dart:io';

import 'package:animated_size_and_fade/animated_size_and_fade.dart';
import 'package:cimagen/modules/NotificationManager.dart';
import 'package:cimagen/pages/Timeline.dart';
import 'package:cimagen/pages/sub/ImageView.dart';
import 'package:cimagen/utils/AppBarController.dart';
import 'package:cimagen/utils/DataModel.dart';
import 'package:cimagen/utils/GitHub.dart';
import 'package:cimagen/utils/ImageManager.dart';
import 'package:cimagen/utils/NavigationService.dart';
import 'package:cimagen/utils/Objectbox.dart';
import 'package:cimagen/utils/SQLite.dart';
import 'package:cimagen/modules/SaveManager.dart';
import 'package:cimagen/utils/ThemeManager.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:floaty_nav_bar/res/floaty_nav_bar.dart';
import 'package:floaty_nav_bar/res/models/floaty_action_button.dart';
import 'package:floaty_nav_bar/res/models/floaty_tab.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

import 'package:path/path.dart' as p;

import 'components/AppBar.dart';
import 'components/LoadingState.dart';
import 'components/NotesSection.dart';
import 'l10n/all_locales.dart';
import 'modules/AudioController.dart';
import 'modules/ConfigManager.dart';
import 'modules/DataManager.dart';

GitHub? githubAPI;
AppBarController? appBarController;
NotificationManager? notificationManager;
AudioController? audioController;
late SharedPreferences prefs;
late ObjectboxDB objectbox;

Future<void> main() async {
  bool debug = false;
  if(debug) {
    runApp(Test());
  } else {
    WidgetsFlutterBinding.ensureInitialized();

    prefs = await SharedPreferences.getInstance();

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
        ChangeNotifierProvider(create: (_) => DataManager()),
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
          child: const WTF()
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
  State<Main> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<Main> with TickerProviderStateMixin{

  static const platform = MethodChannel('app.channel.shared.data');
  String dataShared = 'No data';

  late PageController _pageViewController;
  int _currentPageIndex = 0; // 3
  bool permissionRequired = false;

  bool loaded = false;
  bool hasError = false;
  String error = '';

  bool _storagePass = false;
  bool _configPass = false;
  bool _obPass = false;
  bool _sqlPass = false;
  bool _imgManagerPass = false;
  bool _dataManagerPass = false;
  bool _saveManagerPass = false;

  @override
  void initState() {
    super.initState();
    _pageViewController = PageController(initialPage: _currentPageIndex);
    initMe();
  }

  Future<void> getSharedText() async {
    if(Platform.isAndroid){
      var sharedData = await platform.invokeMethod('getSharedText');
      if (mounted && sharedData != null) {
        showDialog<String>(
          context: context,
          builder: (BuildContext context) => const AlertDialog(
              content: LinearProgressIndicator()
          ),
        );
        if(isImageUrl(sharedData)){
          // blyat
          Uri parse = Uri.parse(sharedData);
          final String e = p.extension(parse.path);
          ImageMeta im = ImageMeta(
              host: Uri(
                  host: parse.host,
                  port: parse.port
              ).toString(),
              re: RenderEngine.unknown,
              fileTypeExtension: e.replaceFirst('.', ''),
              fullNetworkPath: sharedData,
          );

          try{
            await im.parseNetworkImage();
            await im.makeImage(makeThumbnail: true);
            if(!mounted) return;
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (context) => ImageView(imageMeta: im)));
          } catch (e){
            if (kDebugMode) {
              print(e);
            }
          }
        }
      }
    }
  }

  Future<void> initMe() async {
    githubAPI = GitHub();
    audioController = AudioController();
    if(Platform.isAndroid){
      bool permissionStatus;
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      AndroidDeviceInfo info = await deviceInfo.androidInfo;

      if (info.version.sdkInt > 32) {
        permissionStatus = await Permission.photos.request().isGranted;
        if(permissionStatus){
          permissionStatus = await Permission.manageExternalStorage.request().isGranted;
          if(permissionStatus){
            next();
          } else if (await Permission.manageExternalStorage.request().isPermanentlyDenied) {
            await openAppSettings();
          } else if (await Permission.manageExternalStorage.request().isDenied) {
            setState(() {
              hasError = true;
              error = 'The application does not have rights to read and write files';
              permissionRequired = true;
            });
          }
        } else if (await Permission.photos.request().isPermanentlyDenied) {
          await openAppSettings();
        } else if (await Permission.photos.request().isDenied) {
          setState(() {
            hasError = true;
            error = 'The application does not have rights to read and write media files';
            permissionRequired = true;
          });
        }
      } else {
        permissionStatus = await Permission.storage.request().isGranted;
        if(permissionStatus){
          next();
        } else if (await Permission.manageExternalStorage.request().isPermanentlyDenied) {
          await openAppSettings();
        } else if (await Permission.manageExternalStorage.request().isDenied) {
          setState(() {
            hasError = true;
            error = 'The application does not have rights to read and write files';
            permissionRequired = true;
          });
        }
      }
    } else {
      next();
    }
  }

  void onDone(){
    getSharedText();
  }

  void next(){
    setState(() {
      _storagePass = true;
    });
    context.read<ConfigManager>().init().then((v){
      onDone();
      setState(() {
        _configPass = true;
      });
      ObjectboxDB.create().then((db) {
        objectbox = db;
        setState(() {
          _obPass = true;
        });
        context.read<SQLite>().init().then((v){
          setState(() {
            _sqlPass = true;
          });
          context.read<ImageManager>().init(context);
          context.read<DataManager>().init().then((v){
            setState(() {
              _imgManagerPass = true;
              _dataManagerPass = true;
            });
            context.read<SaveManager>().init(context).then((v){
              setState(() {
                _saveManagerPass = true;
                loaded = true;
              });
            });
          }).catchError((e){
            if (kDebugMode) print(e);
            setState(() {
              error = 'Database loading error\n$e';
              hasError = true;
            });
          });
        }).catchError((e){
          if (kDebugMode) print(e);
          setState(() {
            error = 'Database loading error\n$e';
            hasError = true;
          });
        });
      }).catchError((e) {
        setState(() {
          error = e.toString();
          hasError = true;
        });
      });
    }).catchError((e){
      if (kDebugMode) print(e);
      setState((){
        error = 'The configuration cannot be loaded';
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
    bool debug = false;

    bool changeNotify = MediaQuery.of(context).size.width < 720;

    return AnimatedSizeAndFade(
      child: loaded ? Scaffold(
        appBar: CAppBar(),
        body: Stack(
          children: [
            PageView(
              physics: const NeverScrollableScrollPhysics(),
              controller: _pageViewController,
              children: <Widget>[
                loaded ? debug ? Column(
                  children: [
                    Text(p.normalize('Z:\stable-diffusion-webui\outputs\txt2img-images\2023-09-20\00001-2591663516.png'))
                  ],
                ) : const Home() : LoadingState(loaded: loaded, error: error),
                loaded ? const Gallery() : LoadingState(loaded: loaded, error: error),
                loaded ? Timeline() : LoadingState(loaded: loaded, error: error),
                loaded ? const Comparison() : LoadingState(loaded: loaded, error: error),
                // loaded ? P404() : LoadingState(loaded: loaded, errorMessage: error),
                // loaded ? P404() : LoadingState(loaded: loaded, errorMessage: error),
                const Settings()
              ],
            ),
            Positioned(
                bottom: 90,
                right: 14,
                child: Container(
                  // color: Colors.red,
                    constraints: BoxConstraints(
                        maxWidth: changeNotify ? MediaQuery.of(context).size.width - 28 : 720,
                        maxHeight: MediaQuery.of(context).size.height - (changeNotify ? 220 : 156)
                    ),
                    child: ChangeNotifierProvider(
                        create: (context) => notificationManager,
                        child:  Consumer<NotificationManager>(
                            builder: (context, manager, child) => SingleChildScrollView(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: manager.notifications.keys.map((key) => NotificationWidget(context, manager, manager.notifications[key]!)).toList()
                              ),
                            )
                        )
                    )
                )
            ),
            if(Platform.isWindows || Platform.isLinux) Align(
              alignment: Alignment.bottomCenter,
              child: FloatyNavBar(
                selectedTab: _currentPageIndex,
                tabs: [
                  FloatyTab(
                    isSelected: _currentPageIndex == 0,
                    onTap: () => _updateCurrentPageIndex(0),
                    title: 'Home',
                    icon: Icon(Icons.inbox),
                    floatyActionButton: FloatyActionButton(
                      icon: const Icon(Icons.chair),
                      onTap: (){

                      },
                    ),
                  ),
                  FloatyTab(
                    isSelected: _currentPageIndex == 1,
                    onTap: () => _updateCurrentPageIndex(1),
                    title: 'Gallery',
                    icon: Icon(Icons.auto_awesome_mosaic_outlined),
                    floatyActionButton: FloatyActionButton(
                      icon: const Icon(Icons.autorenew),
                      onTap: (){

                      },
                    ),
                  ),
                  FloatyTab(
                    isSelected: _currentPageIndex == 2,
                    onTap: () => _updateCurrentPageIndex(2),
                    title: 'Render History',
                    icon: Icon(Icons.account_tree_sharp),
                    floatyActionButton: FloatyActionButton(
                      icon: const Icon(Icons.auto_graph),
                      onTap: (){

                      },
                    ),
                  ),
                  FloatyTab(
                    isSelected: _currentPageIndex == 3,
                    onTap: () => _updateCurrentPageIndex(3),
                    title: 'Comparison',
                    icon: Icon(Icons.compare),
                    floatyActionButton: FloatyActionButton(
                      icon: const Icon(Icons.share),
                      onTap: (){

                      },
                    ),
                  ),
                  FloatyTab(
                    isSelected: _currentPageIndex == 4,
                    onTap: () => _updateCurrentPageIndex(4),
                    title: 'Settings',
                    icon: Icon(Icons.settings),
                  ),
                ],
              ),
            )
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
        bottomNavigationBar: !(Platform.isWindows || Platform.isLinux) ? NavigationBar(
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
              enabled: false,
            ),
            NavigationDestination(
              icon: Icon(Icons.add_to_photos_outlined),
              selectedIcon: Icon(Icons.add_to_photos),
              label: 'Comparison',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ) : null,
      ) : Scaffold(
        body: SafeArea(
          child: hasError ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(Icons.error_outline, size: 50, color: Colors.redAccent),
                  ],
                ),
                const Gap(4),
                Text('Oops, there seems to be a error', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                Text(error, style: TextStyle(color: Colors.grey)),
                const Gap(7),
                MaterialButton(onPressed: (){
                  print(context.read<DataManager>().error);
                }, child: Text('Retry'))
              ],
            ),
          ) : Center(
            child: Column(
              children: [
                Text('Storage $_storagePass\n'
                    'Config: $_configPass\n'
                    'ObjectBox: $_obPass\n'
                    'SQL: $_sqlPass\n'
                    'ImageManager: $_imgManagerPass\n'
                    'DataManager: $_dataManagerPass\n'
                    'SaveManager: $_saveManagerPass'),
                LinearProgressIndicator()
              ],
            ),
          ),
        ),
      ),
    );
  }

  // bool _storagePass = false;
  // bool _configPass = false;
  // bool _obPass = false;
  // bool _sqlPass = false;
  // bool _imgManagerPass = false;
  // bool _dataManagerPass = false;
  // bool _saveManagerPass = false;

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
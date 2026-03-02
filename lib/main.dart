import 'dart:async';
import 'dart:io';

import 'package:animated_size_and_fade/animated_size_and_fade.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cimagen/components/SimpleWindowBar.dart';
import 'package:cimagen/modules/NotificationManager.dart';
import 'package:cimagen/pages/Timeline.dart';
import 'package:cimagen/pages/sub/E621Search.dart';
import 'package:cimagen/pages/sub/ImageView.dart';
import 'package:cimagen/utils/AppBarController.dart';
import 'package:cimagen/utils/DBExceptions.dart';
import 'package:cimagen/utils/DataModel.dart';
import 'package:cimagen/utils/GitHub.dart';
import 'package:cimagen/utils/ImageManager.dart';
import 'package:cimagen/modules/Objectbox.dart';
import 'package:cimagen/modules/SQLite.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:floaty_nav_bar/res/floaty_nav_bar.dart';
import 'package:floaty_nav_bar/res/models/floaty_tab.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:image_background_remover/image_background_remover.dart';
import 'package:lottie/lottie.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:feedback/feedback.dart';
import 'package:cimagen/Utils.dart';
import 'package:cimagen/pages/Comparison.dart';
import 'package:cimagen/pages/Gallery.dart';
import 'package:cimagen/pages/Home.dart';
import 'package:cimagen/pages/Settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:system_theme/system_theme.dart';

import 'package:path/path.dart' as p;
import 'package:intl/locale.dart' as intl;

import 'components/AppBar.dart';
import 'components/LoadingState.dart';
import 'components/NotesSection.dart';
import 'constants.dart';
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
late SQLite sqLite;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ScreenUtil.ensureScreenSize();
  try {
    await BackgroundRemover.instance.initializeOrt();
    debugPrint('ONNX runtime initialized successfully');
  } catch (e) {
    debugPrint('ONNX init failed: $e');
  }
  await SystemTheme.accentColor.load();
  prefs = await SharedPreferences.getInstance();

  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  userAgent = "CImaGen/${packageInfo.version} (platform; ${Platform.isAndroid ? 'android' : Platform.isWindows ? 'windows' : Platform.isIOS ? 'IOS' : Platform.isLinux ? 'linux' : Platform.isFuchsia ? 'fuchsia' : Platform.isMacOS ? 'MacOs' : 'Unknown'})";

  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    WindowManager.instance.setMinimumSize(const Size(450, 450));
  }
  runApp(Base());

  doWhenWindowReady(() {
    const initialSize = Size(1280, 968);
    appWindow.minSize = initialSize;
    //appWindow.size = initialSize;
    //appWindow.alignment = Alignment.center;
    appWindow.show();
  });
}

class Base extends StatelessWidget {

  Base({super.key}) {
    audioController = AudioController()..init();
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
        ChangeNotifierProvider(create: (_) => ImageManager()),
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
          child: Consumer(
            builder: (ctx, provider, child) {
              ScreenUtil.init(ctx);
              return SystemThemeBuilder(
                  builder: (BuildContext context, SystemAccentColor accent) {
                    intl.Locale? parsedLocale = (prefs.getString('language') ?? 'default') == 'default' ? null : intl.Locale.tryParse(prefs.getString('language')!);
                    return MaterialApp(
                        title: 'CImaGen',
                        navigatorKey: kBaseNavigatorKey,
                        theme: ThemeData(
                          fontFamily: 'Poppins',
                          colorScheme: ColorScheme.fromSeed(seedColor: accent.accent, brightness: Brightness.light),
                          useMaterial3: true,
                        ),
                        darkTheme: ThemeData(
                          fontFamily: 'Poppins',
                          colorScheme: ColorScheme.fromSeed(seedColor: accent.accent, brightness: Brightness.dark).copyWith(
                            onSecondary: Color(0xffeeeaff),
                            background: Colors.red,
                            onBackground: Colors.redAccent,
                            // onSurface: const Color(0xFF1a1c20),
                            //surfaceContainerHighest: Color(0xff725cff),
                            surface: const Color(0xFF1a1c20),
                          ),
                          useMaterial3: true,
                        ).copyWith(
                          scaffoldBackgroundColor: const Color(0xFF131517),
                          dividerColor: const Color(0xFF2d2f32),
                          dividerTheme: const DividerThemeData(
                            color: Color(0xFF2d2f32),
                          ),
                        ),
                        localizationsDelegates: [
                          FlutterI18nDelegate(
                              translationLoader: FileTranslationLoader(
                                  useCountryCode: true,
                                  fallbackFile: 'en_US',
                                  basePath: "assets/i18n",
                                  forcedLocale: parsedLocale != null ? Locale.fromSubtags(
                                      languageCode: parsedLocale.languageCode,
                                      countryCode: parsedLocale.countryCode,
                                      scriptCode: parsedLocale.scriptCode
                                  ) : null
                              )
                          ),
                          GlobalMaterialLocalizations.delegate,
                          GlobalWidgetsLocalizations.delegate
                        ],
                        debugShowCheckedModeBanner: false,
                        builder: FlutterI18n.rootAppBuilder(),
                        home: const Main()
                    );
                  }
              );
            }
          )
      )
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
  final _fabKey = GlobalKey<ExpandableFabState>();
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
    if(Platform.isAndroid){
      bool permissionStatus;
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      AndroidDeviceInfo info = await deviceInfo.androidInfo;

      if (info.version.sdkInt > 32) {
        permissionStatus = await Permission.photos.request().isGranted;
        if(permissionStatus){
          permissionStatus = await Permission.manageExternalStorage.request().isGranted;
          if(permissionStatus){
            tryLoad();
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
          tryLoad();
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
      tryLoad();
    }
  }

  void onDone(){
    getSharedText();
  }

  void tryLoad(){
    setState(() {
      _storagePass = true;
    });
    context.read<ConfigManager>().init().then((v){
      onDone();
      setState(() {
        _configPass = true;
      });
      sqLite = SQLite();
      sqLite.init().then((v){
        setState(() {
          _sqlPass = true;
        });
        sqLite.checkDBErrors().catchError((error, stack) {
          notificationManager!.show(
            thumbnail: const Icon(Icons.warning, color: Colors.amberAccent),
            title: 'SQL problem',
            description: 'Error: $error',
            // content: ElevatedButton(
            //     onPressed: () => init(),
            //     child: const Text("Try again", style: TextStyle(fontSize: 12))
            // )
          );
          audioController!.play(NtSound.wrong);
          if (error is DatabaseCheckException) {

          } else {

          }
        });
        context.read<ImageManager>().init(context);
        context.read<DataManager>().init().then((v){
          setState(() {
            _imgManagerPass = true;
            _dataManagerPass = true;
            loaded = true;
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
      // ObjectboxDB.create().then((db) {
      //   objectbox = db;
      //   setState(() {
      //     _obPass = true;
      //   });
      //
      // }).catchError((e) {
      //   setState(() {
      //     error = e.toString();
      //     hasError = true;
      //   });
      // });
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
        body: Stack(
          children: [
            Positioned.fill(
              child: Column(
                children: [
                  SizedBox(
                    height: 92,
                  ),
                  Expanded(
                    child: PageView(
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
                  )
                ],
              ),
            ),
            Positioned(child: CAppBar()),
            // Notifications
            Positioned(
              bottom: 90,
              right: 14,
              child: Container(
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
                        children: manager.notifications.map((obj) => NotificationWidget(
                          key: ValueKey(obj.id),
                          notificationObject: obj,
                          manager: manager,
                        )).toList()
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
                    titleStyle: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                    onTap: () => _updateCurrentPageIndex(0),
                    title: 'Home',
                    icon: LottieTabIcon(
                      isSelected: _currentPageIndex == 0,
                      asset: 'assets/icons/lottie/direct normal.json',
                    ),
                    // floatyActionButton: FloatyActionButton(
                    //   icon: const Icon(Icons.chair),
                    //   onTap: (){
                    //     Navigator.push(context, MaterialPageRoute(builder: (context) => YearEndResults(year: 2025)));
                    //   },
                    // ),
                  ),
                  FloatyTab(
                    isSelected: _currentPageIndex == 1,
                    titleStyle: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                    onTap: () => _updateCurrentPageIndex(1),
                    title: 'Gallery',
                    icon: LottieTabIcon(
                      isSelected: _currentPageIndex == 1,
                      asset: 'assets/icons/lottie/element-4.json',
                    ),
                    // floatyActionButton: FloatyActionButton(
                    //   icon: const Icon(Icons.autorenew),
                    //   onTap: (){
                    //
                    //   },
                    // ),
                  ),
                  FloatyTab(
                    isSelected: _currentPageIndex == 2,
                    titleStyle: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                    onTap: () => _updateCurrentPageIndex(2),
                    title: 'Render History',
                    icon: LottieTabIcon(
                      isSelected: _currentPageIndex == 2,
                      asset: 'assets/icons/lottie/data-2.json',
                    ),
                    // floatyActionButton: FloatyActionButton(
                    //   icon: const Icon(Icons.auto_graph),
                    //   onTap: (){
                    //
                    //   },
                    // ),
                  ),
                  FloatyTab(
                    isSelected: _currentPageIndex == 3,
                    titleStyle: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                    onTap: () => _updateCurrentPageIndex(3),
                    title: 'Comparison',
                    icon: LottieTabIcon(
                      isSelected: _currentPageIndex == 3,
                      asset: 'assets/icons/lottie/clipboard.json',
                    ),
                    // floatyActionButton: FloatyActionButton(
                    //   icon: const Icon(Icons.share),
                    //   onTap: (){
                    //
                    //   },
                    // ),
                  ),
                  FloatyTab(
                    isSelected: _currentPageIndex == 4,
                    titleStyle: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                    onTap: () => _updateCurrentPageIndex(4),
                    title: 'Settings',
                    icon: LottieTabIcon(
                      isSelected: _currentPageIndex == 4,
                      asset: 'assets/icons/lottie/setting.json',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButtonLocation: ExpandableFab.location,
        floatingActionButton: ExpandableFab(
          key: _fabKey,
          duration: Duration(milliseconds: 150),
          //type: ExpandableFabType.side,
          distance: 70,
          childrenAnimation: ExpandableFabAnimation.none,
          children: [
            FloatingActionButton.small(
              heroTag: null,
              child: const Icon(Icons.note),
              onPressed: () {
                _showModalBottomSheet(context);
                final state = _fabKey.currentState;
                if (state != null) {
                  state.toggle();
                }
              },
            ),
            FloatingActionButton.small(
              heroTag: null,
              child: const Icon(Icons.search),
              onPressed: () {
                showModalBottomSheet(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 95 / 100,
                    minWidth: 100,
                    maxWidth: MediaQuery.of(context).size.width * 95 / 100
                  ),
                  context: context,
                  useSafeArea: true,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(30),
                      )
                  ),
                  builder: (context) => const E621Search(),
                );
                final state = _fabKey.currentState;
                if (state != null) {
                  state.toggle();
                }
              },
            ),
          ],
        ),
        // floatingActionButton: FloatingActionButton(
        //   onPressed:(){
        //     _showModalBottomSheet(context);
        //     //theme.setTheme(theme.getTheme==lightTheme?darkTheme:lightTheme);
        //   },
        //   tooltip: 'Notes',
        //   child: const Icon(Icons.note),
        // ),
        bottomNavigationBar: changeNotify ? NavigationBar(
          height: 70,
          backgroundColor: Theme.of(context).colorScheme.surface,
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
        appBar: SimpleWindowBar(),
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
                SelectableText(error, style: TextStyle(color: Colors.grey)),
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

class LottieTabIcon extends StatefulWidget {
  final bool isSelected;
  final String asset;

  const LottieTabIcon({super.key, required this.isSelected, required this.asset});

  @override
  State<LottieTabIcon> createState() => _LottieTabIconState();
}

class _LottieTabIconState extends State<LottieTabIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));

    if (widget.isSelected) _controller.forward();
  }

  @override
  void didUpdateWidget(LottieTabIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _controller.reset();
      _controller.forward();
    } else if (!widget.isSelected) {
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        widget.isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).iconTheme.color!,
        BlendMode.srcIn,
      ),
      child: Lottie.asset(
        widget.asset,
        controller: _controller,
        width: 30,
        height: 30,
        fit: BoxFit.fill,
        onLoaded: (composition) => _controller.duration = composition.duration,
      ),
    );
  }
}

class MigrationProgress {
  final int processed;
  final int total;
  final double percent;
  final String stage;

  MigrationProgress({
    required this.processed,
    required this.total,
    required this.percent,
    required this.stage,
  });
}
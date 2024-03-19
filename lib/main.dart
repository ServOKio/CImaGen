import 'dart:io';

import 'package:cimagen/pages/Timeline.dart';
import 'package:cimagen/utils/DataModel.dart';
import 'package:cimagen/utils/ImageManager.dart';
import 'package:cimagen/utils/NavigationService.dart';
import 'package:cimagen/utils/SQLite.dart';
import 'package:cimagen/utils/ThemeManager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:feedback/feedback.dart';
import 'package:cimagen/Utils.dart';
import 'package:cimagen/pages/Comparison.dart';
import 'package:cimagen/pages/Gallery.dart';
import 'package:cimagen/pages/Home.dart';
import 'package:cimagen/pages/P404.dart';
import 'package:cimagen/pages/Settings.dart';
import 'package:window_manager/window_manager.dart';

import 'components/AppBar.dart';

Future<void> main() async {
  //runApp(Test());
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  if (Platform.isWindows) {
    WindowManager.instance.setMinimumSize(const Size(450, 450));
    // WindowManager.instance.setMaximumSize(const Size(1200, 720));
  }
  runApp(MyApp());
}

class Test extends StatelessWidget {
  const Test({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text("Demo Project"),
        ),
        body: const Center(child: Text("Hello World!!!")),
      ),
    );
  }
}

// class MyAppTheme {
//
//   bool isDark = true;
//
//   MyAppTheme({required this.isDark});
//
//   Color newsBlock = Color(0xff333333);
//   Color themeMainColor = Colors.red;
//   Color themeTimeStamp = Colors.grey;
//   Color newsBlockTitleSub = Color(0xffD5D5D5);
//   Color link = Color(0xffBBDDEE);
//   Color pagesButtons = Colors.red;
//   Color pagesButtonsPressed = const Color(0x77f44336);
//
//   void init(){
//     newsBlock = isDark ? Color(0xff333333) : Color(0xff5C72CB);
//     themeMainColor = isDark ? const Color(0xff725cff) : Color(0xff93d0ea);
//     themeTimeStamp = isDark ? Colors.grey : Colors.white70;
//     newsBlockTitleSub = Color(0xffD5D5D5);
//     link = Color(0xffBBDDEE);
//     pagesButtons = isDark ? const Color(0xff725cff) : Color(0xff445fca);
//     pagesButtonsPressed = isDark ? const Color(0x77f44336) : Color(0xff667ddb);
//   }
//
//   /// Default constructor
//
//   ThemeData get themeData {
//     /// Create a TextTheme and ColorScheme, that we can use to generate ThemeData
//     TextTheme txtTheme = (ThemeData.dark()).textTheme;
//     ColorScheme colorScheme = ColorScheme(
//       // Decide how you want to apply your own custom them, to the MaterialApp
//         brightness: Brightness.dark,
//         primary: const Color(0xff725cff),
//         onPrimary: const Color(0xffc0eeff),
//
//         secondary: const Color(0xff6a6798), //dont
//         onSecondary: const Color(0xffeeeaff),//dont
//
//         background: const Color(0xff1A1A1A),
//         onBackground: const Color(0xff725cff),
//
//         surface: isDark ? const Color(0xFF222222): const Color(0xFF31469b),
//         onSurface: const Color(0xffe2dbff),
//
//         error: Colors.red,
//         onError: Colors.white
//     );
//
//     /// Now that we have ColorScheme and TextTheme, we can create the ThemeData
//     ThemeData t = ThemeData.from(
//         textTheme: txtTheme,
//         colorScheme: colorScheme
//     ).copyWith(
//       primaryColor: isDark ? const Color(0xFF222222) : const Color(0xFF31469b),
//       scaffoldBackgroundColor: isDark ?
//       const Color(0xFF191919) :
//       const Color(0xFF788BD6),
//       highlightColor: const Color(0xFF3D3D3D),
//     );
//
//     return t;
//   }
// }
//
class MyApp extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DataModel()),
        ChangeNotifierProvider(create: (_) => ConfigManager()),
        ChangeNotifierProvider(create: (_) => SQLite()),
        ChangeNotifierProvider(create: (_) => ImageManager()),
        ChangeNotifierProvider(create: (_) => ThemeManager(darkTheme)),
      ],
      child: const BetterFeedback(
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
  late TabController _tabController;
  int _currentPageIndex = 3;

  bool loaded = false;

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
    context.read<ConfigManager>().init().then((v) => context.read<SQLite>().init().then((v){
      loaded = true;
      context.read<ImageManager>().init(context);
    }));

    context.read<DataModel>().jumpToTab = _updateCurrentPageIndex;
  }

  @override
  void dispose() {
    super.dispose();
    _pageViewController.dispose();
    _tabController.dispose();
  }

  // void _showModalBottomSheet(BuildContext context) {
  //   showModalBottomSheet(
  //     context: context,
  //     isScrollControlled: true,
  //     shape: const RoundedRectangleBorder(
  //         borderRadius: BorderRadius.vertical(
  //           top: Radius.circular(30),
  //         )
  //     ),
  //     builder: (context) => DraggableScrollableSheet(
  //         initialChildSize: 0.4,
  //         maxChildSize: 0.9,
  //         minChildSize: 0.32,
  //         expand: false,
  //         builder: (context, scrollController) {
  //           return SingleChildScrollView(
  //             controller: scrollController,
  //             child: const SignInOptionsScreen(),
  //           );
  //         }
  //     ),
  //   );
  // }

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
          child: Drawer(
              child: Container(
                  child: Stack(
                      children: [
                        Column(
                            children: <Widget>[
                              Container(child: Center(child: Text('gdfg', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)))),
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
          )
      ),
      appBar: CAppBar(),
      body: PageView(
        physics: const NeverScrollableScrollPhysics(),
        controller: _pageViewController,
        onPageChanged: _handlePageViewChanged,
        children: <Widget>[
          loaded ? const Home() : Text(''),
          loaded ? const Gallery() : Text(''),
          loaded ? const Timeline() : Text(''),
          loaded ? const Comparison() : Text(''),
          loaded ? P404() : Text(''),
          loaded ? P404() : Text(''),
          loaded ? const Settings() : Text(''),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed:(){
          //_showModalBottomSheet(context);
          theme.setTheme(theme.getTheme==lightTheme?darkTheme:lightTheme);
        },
        tooltip: 'Notes',
        child: const Icon(Icons.note),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.all_inbox),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome_mosaic),
            label: 'Gallery',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_tree_sharp),
            label: 'Render History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_to_photos),
            label: 'Comparison',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.border_all_sharp),
            label: 'Grid rebuild',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.amp_stories),
            label: 'Maybe',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _currentPageIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Theme.of(context).colorScheme.primary.withOpacity(0.5),
        onTap: (index){
          _updateCurrentPageIndex(index);
        },
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
    if (!_isOnDesktopAndWeb) {
      return;
    }
    _tabController.index = currentPageIndex;
    setState(() {
      _currentPageIndex = currentPageIndex;
    });
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

class SignInOptionsScreen extends StatelessWidget {
  const SignInOptionsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: AlignmentDirectional.topCenter,
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -15,
          child: Container(
            width: 60,
            height: 7,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: Colors.white,
            ),
          ),
        ),
        const Column(children: [
          Center(
            child: Text(
              'OR',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ])
      ],
    );
  }
}
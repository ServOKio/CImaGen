import 'package:cimagen/pages/sub/categories/LoraMakerList.dart';
import 'package:floaty_nav_bar/res/floaty_nav_bar.dart';
import 'package:floaty_nav_bar/res/models/floaty_action_button.dart';
import 'package:floaty_nav_bar/res/models/floaty_tab.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../components/Animations.dart';

class LoraMaker extends StatefulWidget{
  LoraProject project;
  LoraMaker({ super.key, required this.project });

  @override
  State<LoraMaker> createState() => _LoraMakerState();
}

class _LoraMakerState extends State<LoraMaker> {
  bool loaded = false;

  late PageController _pageViewController;
  int _currentPageIndex = 0;

  // Settings
  TrainType trainType = TrainType.unknown;
  late TextEditingController projectNameController;
  InitialData initialData = InitialData.unknown;

  @override
  void initState() {
    super.initState();
    projectNameController = TextEditingController();
    projectNameController.text = widget.project.name;
    _pageViewController = PageController(initialPage: _currentPageIndex);
  }

  @override
  void dispose() {
    super.dispose();
    _pageViewController.dispose();
    projectNameController.dispose();
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

  @override
  Widget build(BuildContext context) {
    AppBar appBar = AppBar(
        title: ShowUp(
          delay: 0,
          child: Text('Lora Maker', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600, fontFamily: 'Montserrat')),
        ),
        elevation: 0,
        actions: []
    );

    double gap = 4;

    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: appBar,
        body: SafeArea(
            child: Stack(
              children: [
                PageView(
                  physics: const NeverScrollableScrollPhysics(),
                  controller: _pageViewController,
                  children: <Widget>[
                    Row(
                      children: [
                        Container(
                            padding: const EdgeInsets.all(6),
                            color: Color(0xff1b1c20),
                            width: 500,
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('I want to train'),
                                  Gap(gap),
                                  DropdownButton(
                                    focusColor: Colors.transparent,
                                    underline: const SizedBox.shrink(),
                                    value: trainType,
                                    itemHeight: 50,
                                    items: const [
                                      DropdownMenuItem<TrainType>(
                                        value: TrainType.unknown,
                                        child: Text('I don\'t know what...', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600, fontFamily: 'Montserrat')),
                                      ),
                                      DropdownMenuItem<TrainType>(
                                        value: TrainType.lora,
                                        child: Text('Lora', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600, fontFamily: 'Montserrat')),
                                      ),
                                      DropdownMenuItem<TrainType>(
                                        value: TrainType.model,
                                        child: Text('Model', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600, fontFamily: 'Montserrat')),
                                      )
                                    ],
                                    onChanged: (TrainType? v) {
                                      if(v != null){
                                        // prefs.setString('remote_version_method', value);
                                        setState(() {
                                          trainType = v;
                                        });
                                        // context.read<ImageManager>().switchGetterAuto();
                                      }
                                    },
                                  ),
                                  Gap(gap),
                                  Text('named'),
                                  Gap(gap),
                                  TextField(
                                    textInputAction: TextInputAction.done,
                                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600, fontFamily: 'Montserrat'),
                                    textAlign: TextAlign.left,
                                    decoration: InputDecoration(

                                      alignLabelWithHint: true,
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                      hint: Text('name ?'),
                                      focusedBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                            width: 1, color: Theme.of(context).colorScheme.primary
                                        ),
                                      )
                                    ),
                                    controller: projectNameController,
                                  ),
                                  Gap(gap),
                                  Text('and I have'),
                                  Gap(gap),
                                  DropdownButton(
                                    focusColor: Colors.transparent,
                                    underline: const SizedBox.shrink(),
                                    value: initialData,
                                    itemHeight: 50,
                                    items: const [
                                      DropdownMenuItem<InitialData>(
                                        value: InitialData.unknown,
                                        child: Text('nothing to start with', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600, fontFamily: 'Montserrat')),
                                      ),
                                      DropdownMenuItem<InitialData>(
                                        value: InitialData.exampleImage,
                                        child: Text('example image', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600, fontFamily: 'Montserrat')),
                                      ),
                                      DropdownMenuItem<InitialData>(
                                        value: InitialData.readymadeDataset,
                                        child: Text('ready-made dataset', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600, fontFamily: 'Montserrat')),
                                      )
                                    ],
                                    onChanged: (InitialData? v) {
                                      if(v != null){
                                        // prefs.setString('remote_version_method', value);
                                        setState(() {
                                          initialData = v;
                                        });
                                        // context.read<ImageManager>().switchGetterAuto();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            )
                        ),
                        Expanded(
                          child: Text('fdf'),
                        )
                      ],
                    ),
                    Text('Finding data'),
                    Text('Dataset'),
                    Text('Setup'),
                    Text('Export'),
                  ],
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: FloatyNavBar(
                    selectedTab: _currentPageIndex,
                    tabs: [
                      FloatyTab(
                        isSelected: _currentPageIndex == 0,
                        onTap: () => _updateCurrentPageIndex(0),
                        title: 'Initialization',
                        icon: Icon(Icons.note),
                      ),
                      FloatyTab(
                        isSelected: _currentPageIndex == 1,
                        onTap: () => _updateCurrentPageIndex(1),
                        title: 'Data search',
                        icon: Icon(Icons.analytics_outlined),
                      ),
                      FloatyTab(
                        isSelected: _currentPageIndex == 2,
                        onTap: () => _updateCurrentPageIndex(2),
                        title: 'Dataset',
                        icon: Icon(Icons.inbox),
                      ),
                      FloatyTab(
                        isSelected: _currentPageIndex == 3,
                        onTap: () => _updateCurrentPageIndex(3),
                        title: 'Setting up',
                        icon: Icon(Icons.swipe),
                      ),
                      FloatyTab(
                        isSelected: _currentPageIndex == 4,
                        onTap: () => _updateCurrentPageIndex(4),
                        title: 'Export',
                        icon: Icon(Icons.dns),
                      ),
                    ],
                  ),
                )
              ],
            )
        )
    );
  }
}

enum TrainType {
  unknown,
  lora,
  model
}

enum InitialData {
  unknown,
  exampleImage,
  readymadeDataset
}
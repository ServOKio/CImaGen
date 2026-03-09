import 'dart:io';

import 'package:flutter/material.dart';

String userAgent = 'CImaGen/Undefined.version';
final GlobalKey<NavigatorState> kBaseNavigatorKey = GlobalKey<NavigatorState>();
const List<String> kSupportedLanguages = ['ru_RU', 'en_US'];
final bool isWindowed = Platform.isMacOS || Platform.isLinux || Platform.isWindows;
final bool isDesktop = Platform.isMacOS || Platform.isLinux || Platform.isWindows;
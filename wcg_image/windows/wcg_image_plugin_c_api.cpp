#include "include/wcg_image/wcg_image_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "wcg_image_plugin.h"

void WcgImagePluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  wcg_image::WcgImagePlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}

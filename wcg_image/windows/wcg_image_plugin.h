#ifndef FLUTTER_PLUGIN_WCG_IMAGE_PLUGIN_H_
#define FLUTTER_PLUGIN_WCG_IMAGE_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/texture_registrar.h>

#include <memory>
#include <vector>

namespace wcg_image {

    class WcgImagePlugin : public flutter::Plugin {
    public:
        static void RegisterWithRegistrar(
                flutter::PluginRegistrarWindows* registrar);

        explicit WcgImagePlugin(flutter::TextureRegistrar* registrar);
        ~WcgImagePlugin() override;

        WcgImagePlugin(const WcgImagePlugin&) = delete;
        WcgImagePlugin& operator=(const WcgImagePlugin&) = delete;

    private:
        void HandleMethodCall(
                const flutter::MethodCall<flutter::EncodableValue>& call,
                std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

        flutter::TextureRegistrar* texture_registrar_ = nullptr;
        int64_t texture_id_ = -1;

        std::vector<uint8_t> pixels_;
        FlutterDesktopPixelBuffer pixel_buffer_{};

        uint32_t width_ = 0;
        uint32_t height_ = 0;

        std::unique_ptr<flutter::PixelBufferTexture> pixel_texture_;
        std::unique_ptr<flutter::TextureVariant> texture_variant_;
    };

}  // namespace wcg_image

#endif

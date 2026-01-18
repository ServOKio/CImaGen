#include <wincodec.h>
#pragma comment(lib, "windowscodecs.lib")


#include "wcg_image_plugin.h"

#include <flutter/standard_method_codec.h>
#include <flutter/encodable_value.h>

// 🔴 Helper function — CPP only (not in header)
static bool LoadImageWIC(
        const std::wstring& path,
        std::vector<uint8_t>& pixels,
        uint32_t& width,
        uint32_t& height) {

    IWICImagingFactory* factory = nullptr;
    IWICBitmapDecoder* decoder = nullptr;
    IWICBitmapFrameDecode* frame = nullptr;
    IWICFormatConverter* converter = nullptr;

    HRESULT hr = CoCreateInstance(
            CLSID_WICImagingFactory,
            nullptr,
            CLSCTX_INPROC_SERVER,
            IID_PPV_ARGS(&factory));
    if (FAILED(hr)) return false;

    hr = factory->CreateDecoderFromFilename(
            path.c_str(),
            nullptr,
            GENERIC_READ,
            WICDecodeMetadataCacheOnLoad,
            &decoder);
    if (FAILED(hr)) goto cleanup;

    hr = decoder->GetFrame(0, &frame);
    if (FAILED(hr)) goto cleanup;

    hr = factory->CreateFormatConverter(&converter);
    if (FAILED(hr)) goto cleanup;

    hr = converter->Initialize(
            frame,
            GUID_WICPixelFormat32bppBGRA,
            WICBitmapDitherTypeNone,
            nullptr,
            0.0,
            WICBitmapPaletteTypeCustom);
    if (FAILED(hr)) goto cleanup;

    frame->GetSize(&width, &height);
    pixels.resize(width * height * 4);

    hr = converter->CopyPixels(
            nullptr,
            width * 4,
            static_cast<UINT>(pixels.size()),
            pixels.data());

    if (FAILED(hr)) goto cleanup;

    // 🔥 BGRA → RGBA fix
    for (size_t i = 0; i < pixels.size(); i += 4) {
        std::swap(pixels[i + 0], pixels[i + 2]);
    }

    cleanup:
    if (converter) converter->Release();
    if (frame) frame->Release();
    if (decoder) decoder->Release();
    if (factory) factory->Release();

    return SUCCEEDED(hr);
}


namespace wcg_image {

    WcgImagePlugin::WcgImagePlugin(flutter::TextureRegistrar* registrar)
            : texture_registrar_(registrar) {}

    WcgImagePlugin::~WcgImagePlugin() {
        if (texture_id_ >= 0) {
            texture_registrar_->UnregisterTexture(texture_id_);
        }
    }

    void WcgImagePlugin::RegisterWithRegistrar(
            flutter::PluginRegistrarWindows* registrar) {

        auto channel =
                std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
                        registrar->messenger(),
                                "wcg_image",
                                &flutter::StandardMethodCodec::GetInstance());

        auto plugin =
                std::make_unique<WcgImagePlugin>(registrar->texture_registrar());

        channel->SetMethodCallHandler(
                [plugin_ptr = plugin.get()](const auto& call, auto result) {
                    plugin_ptr->HandleMethodCall(call, std::move(result));
                });

        registrar->AddPlugin(std::move(plugin));
    }

    void WcgImagePlugin::HandleMethodCall(
            const flutter::MethodCall<flutter::EncodableValue>& call,
            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

        if (call.method_name() == "createTexture") {
            const auto* args =
                    std::get_if<flutter::EncodableMap>(call.arguments());

            std::wstring path;

            if (args) {
                auto it = args->find(flutter::EncodableValue("path"));
                if (it != args->end()) {
                    path = std::wstring(
                            std::get<std::string>(it->second).begin(),
                            std::get<std::string>(it->second).end());
                }
            }

            uint32_t width = 0, height = 0;

            if (!LoadImageWIC(path, pixels_, width, height)) {
                result->Error("load_failed", "Failed to load image");
                return;
            }

            // ✅ STORE THEM
            width_ = width;
            height_ = height;

            pixel_buffer_.width = width;
            pixel_buffer_.height = height;
            pixel_buffer_.buffer = pixels_.data();

            pixel_texture_ = std::make_unique<flutter::PixelBufferTexture>(
                    [this](size_t, size_t)
                            -> const FlutterDesktopPixelBuffer* {
                        return &pixel_buffer_;
                    });

            texture_variant_ =
                    std::make_unique<flutter::TextureVariant>(*pixel_texture_);

            texture_id_ =
                    texture_registrar_->RegisterTexture(texture_variant_.get());

            texture_registrar_->MarkTextureFrameAvailable(texture_id_);

            result->Success(flutter::EncodableValue(
                    flutter::EncodableMap{
                            {flutter::EncodableValue("id"), flutter::EncodableValue(texture_id_)},
                            {flutter::EncodableValue("width"), flutter::EncodableValue((int)width_)},
                            {flutter::EncodableValue("height"), flutter::EncodableValue((int)height_)}
                    }
            ));
        }

        if (call.method_name() == "disposeTexture") {
            if (texture_id_ >= 0) {
                texture_registrar_->UnregisterTexture(texture_id_);
                texture_id_ = -1;
            }
            texture_variant_.reset();
            pixel_texture_.reset();
            result->Success();
            return;
        }

        result->NotImplemented();
    }

}  // namespace wcg_image
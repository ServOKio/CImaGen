#include "wcg_image_plugin.h"

#include <flutter/standard_method_codec.h>
#include <flutter/encodable_value.h>

#include <d2d1_3.h>
#include <d3d11_4.h>
#include <dxgi1_6.h>
#include <wincodec.h>
#include <DirectXPackedVector.h>
#include <wrl/client.h>

#pragma comment(lib, "d2d1.lib")
#pragma comment(lib, "d3d11.lib")
#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "windowscodecs.lib")

using Microsoft::WRL::ComPtr;

namespace wcg_image {

    void LogToFlutterConsole(const std::wstring& ws) {
        int size_needed = WideCharToMultiByte(
                CP_UTF8, 0,
                ws.c_str(),
                (int)ws.size(),
                NULL, 0,
                NULL, NULL);

        std::string utf8(size_needed, 0);

        WideCharToMultiByte(
                CP_UTF8, 0,
                ws.c_str(),
                (int)ws.size(),
                &utf8[0],
                size_needed,
                NULL, NULL);

        // Flush to make sure it appears immediately
        printf("%s\n", utf8.c_str());
        fflush(stdout);
    }

    static bool CreateD3DDevice(
            ComPtr<ID3D11Device>& d3dDevice,
            ComPtr<ID3D11DeviceContext>& d3dContext) {

        UINT flags = D3D11_CREATE_DEVICE_BGRA_SUPPORT;

        D3D_FEATURE_LEVEL levels[] = {
                D3D_FEATURE_LEVEL_11_1,
                D3D_FEATURE_LEVEL_11_0
        };

        D3D_FEATURE_LEVEL obtained;

        HRESULT hr = D3D11CreateDevice(
                nullptr,
                D3D_DRIVER_TYPE_HARDWARE,
                nullptr,
                flags,
                levels,
                2,
                D3D11_SDK_VERSION,
                &d3dDevice,
                &obtained,
                &d3dContext
        );

        return SUCCEEDED(hr);
    }

    static bool CreateD2DDevice(
            ID3D11Device* d3dDevice,
            ComPtr<ID2D1Device>& d2dDevice,
            ComPtr<ID2D1DeviceContext>& d2dContext) {

        ComPtr<IDXGIDevice> dxgiDevice;
        if (FAILED(d3dDevice->QueryInterface(IID_PPV_ARGS(&dxgiDevice))))
            return false;

        ComPtr<ID2D1Factory1> factory;
        if (FAILED(D2D1CreateFactory(
                D2D1_FACTORY_TYPE_SINGLE_THREADED,
                factory.GetAddressOf())))
            return false;

        if (FAILED(factory->CreateDevice(dxgiDevice.Get(), &d2dDevice)))
            return false;

        if (FAILED(d2dDevice->CreateDeviceContext(
                D2D1_DEVICE_CONTEXT_OPTIONS_NONE,
                &d2dContext)))
            return false;

        return true;
    }

    static bool CheckHR(HRESULT hr, const char* step) {
        if (FAILED(hr)) {
            printf("FAILED: 0x%08lX\n", hr);
            return false;
        }
        return true;
    }

    static bool LoadColorManagedImage(
            const std::wstring& path,
            std::vector<uint8_t>& outPixels,
            uint32_t& width,
            uint32_t& height) {

        LogToFlutterConsole(L"1");
        HRESULT hr;

        ComPtr<IWICImagingFactory> wicFactory;
        hr = CoCreateInstance(
                CLSID_WICImagingFactory,
                nullptr,
                CLSCTX_INPROC_SERVER,
                IID_PPV_ARGS(&wicFactory));
        if (!CheckHR(hr, "Create WIC factory")) return false;
        LogToFlutterConsole(L"2");

        ComPtr<IWICBitmapDecoder> decoder;
        hr = wicFactory->CreateDecoderFromFilename(
                path.c_str(),
                nullptr,
                GENERIC_READ,
                WICDecodeMetadataCacheOnLoad,
                &decoder);
        if (!CheckHR(hr, "CreateDecoderFromFilename")) return false;
        LogToFlutterConsole(L"3");

        ComPtr<IWICBitmapFrameDecode> frame;
        hr = decoder->GetFrame(0, &frame);
        if (!CheckHR(hr, "GetFrame")) return false;
        LogToFlutterConsole(L"4");

        hr = frame->GetSize(&width, &height);
        if (!CheckHR(hr, "GetSize")) return false;
        LogToFlutterConsole(L"5");

        // --- Get embedded ICC profile ---
        UINT count = 0;
        frame->GetColorContexts(0, nullptr, &count);

        ComPtr<IWICColorContext> wicColorContext;
        if (count > 0) {
            hr = wicFactory->CreateColorContext(&wicColorContext);
            if (!CheckHR(hr, "CreateColorContext")) return false;
            hr = frame->GetColorContexts(1, wicColorContext.GetAddressOf(), &count);
            if (!CheckHR(hr, "GetColorContexts")) return false;
        }
        LogToFlutterConsole(L"6");

        // --- Create D3D + D2D ---
        ComPtr<ID3D11Device> d3dDevice;
        ComPtr<ID3D11DeviceContext> d3dContext;
        if (!CreateD3DDevice(d3dDevice, d3dContext)) {
            LogToFlutterConsole(L"CreateD3DDevice failed");
            return false;
        }
        LogToFlutterConsole(L"7");

        ComPtr<ID2D1Device> d2dDevice;
        ComPtr<ID2D1DeviceContext> d2dContext;
        if (!CreateD2DDevice(d3dDevice.Get(), d2dDevice, d2dContext)) {
            LogToFlutterConsole(L"CreateD2DDevice failed");
            return false;
        }
        LogToFlutterConsole(L"8");

        // --- Create D2D color context from embedded ICC (if exists) ---
        ComPtr<ID2D1ColorContext> srcColorContext;
        if (wicColorContext) {
            d2dContext->CreateColorContextFromWicColorContext(
                    wicColorContext.Get(),
                    &srcColorContext);
        }
        LogToFlutterConsole(L"9");

        // --- Convert WIC frame to a D2D bitmap (source bitmap) ---
        ComPtr<IWICFormatConverter> converter;
        hr = wicFactory->CreateFormatConverter(&converter);
        if (!CheckHR(hr, "CreateFormatConverter")) return false;
        LogToFlutterConsole(L"10");

        hr = converter->Initialize(
                frame.Get(),
                GUID_WICPixelFormat32bppPBGRA,
                WICBitmapDitherTypeNone,
                nullptr,
                0.0,
                WICBitmapPaletteTypeCustom);
        if (!CheckHR(hr, "FormatConverter::Initialize")) return false;
        LogToFlutterConsole(L"11");

        ComPtr<ID2D1Bitmap1> sourceBitmap;
        D2D1_BITMAP_PROPERTIES1 sourceProps =
                D2D1::BitmapProperties1(
                        D2D1_BITMAP_OPTIONS_NONE,
                        D2D1::PixelFormat(DXGI_FORMAT_B8G8R8A8_UNORM, D2D1_ALPHA_MODE_PREMULTIPLIED),
                        96, 96,
                        srcColorContext.Get());

        hr = d2dContext->CreateBitmapFromWicBitmap(converter.Get(), &sourceProps, &sourceBitmap);
        if (!CheckHR(hr, "CreateBitmapFromWicBitmap")) return false;
        LogToFlutterConsole(L"12");

        // --- Create a render-target bitmap (we will draw into this) ---
        ComPtr<ID2D1Bitmap1> targetBitmap;
        D2D1_BITMAP_PROPERTIES1 targetProps =
                D2D1::BitmapProperties1(
                        D2D1_BITMAP_OPTIONS_TARGET,
                        D2D1::PixelFormat(DXGI_FORMAT_R16G16B16A16_FLOAT, D2D1_ALPHA_MODE_PREMULTIPLIED),
                        96, 96);
        hr = d2dContext->CreateBitmap(D2D1::SizeU(width, height), nullptr, 0, &targetProps, &targetBitmap);
        if (!CheckHR(hr, "Create targetBitmap")) return false;
        LogToFlutterConsole(L"13");

        // Draw the source onto the target (D2D will perform color management because source had a color context)
        d2dContext->SetTarget(targetBitmap.Get());
        d2dContext->BeginDraw();
        d2dContext->Clear(); // optional
        d2dContext->DrawBitmap(sourceBitmap.Get());
        hr = d2dContext->EndDraw();
        if (!CheckHR(hr, "EndDraw")) return false;
        LogToFlutterConsole(L"14 (drawn into targetBitmap)");

        ComPtr<ID2D1Bitmap1> cpuBitmap;
        D2D1_BITMAP_PROPERTIES1 cpuProps =
                D2D1::BitmapProperties1(
                        static_cast<D2D1_BITMAP_OPTIONS>(D2D1_BITMAP_OPTIONS_CPU_READ | D2D1_BITMAP_OPTIONS_CANNOT_DRAW),
                        D2D1::PixelFormat(DXGI_FORMAT_R16G16B16A16_FLOAT, D2D1_ALPHA_MODE_PREMULTIPLIED),
                        96, 96);

        hr = d2dContext->CreateBitmap(D2D1::SizeU(width, height), nullptr, 0, &cpuProps, &cpuBitmap);
        if (!CheckHR(hr, "Create CPU bitmap")) return false;
        LogToFlutterConsole(L"Created cpuBitmap");

        hr = cpuBitmap->CopyFromBitmap(nullptr, targetBitmap.Get(), nullptr);
        if (!CheckHR(hr, "cpuBitmap::CopyFromBitmap")) return false;
        LogToFlutterConsole(L"Copied into cpuBitmap");

        D2D1_MAPPED_RECT mapped;
        hr = cpuBitmap->Map(D2D1_MAP_OPTIONS_READ, &mapped);
        if (!CheckHR(hr, "cpuBitmap::Map")) return false;
        LogToFlutterConsole(L"cpuBitmap mapped");

        outPixels.resize(width * height * 4); // Still 8-bit output
        for (uint32_t y = 0; y < height; ++y) {
            uint8_t* rowStart = mapped.bits + y * mapped.pitch;
            uint8_t* dst = outPixels.data() + y * width * 4;
            for (uint32_t x = 0; x < width; ++x) {
                uint16_t* channels = reinterpret_cast<uint16_t*>(rowStart + x * 8); // 8 bytes per pixel (4 * 2)

                float r = DirectX::PackedVector::XMConvertHalfToFloat(channels[0]);
                float g = DirectX::PackedVector::XMConvertHalfToFloat(channels[1]);
                float b = DirectX::PackedVector::XMConvertHalfToFloat(channels[2]);
                float a = DirectX::PackedVector::XMConvertHalfToFloat(channels[3]);

                // Simple Reinhard tone mapping (per channel, preserves white point)
                r = r / (r + 1.0f);
                g = g / (g + 1.0f);
                b = b / (b + 1.0f);

                // Convert to 8-bit (clamp for safety, though tone map should be [0,1])
                dst[0] = static_cast<uint8_t>((std::max)(0.0f, (std::min)(255.0f, r * 255.0f + 0.5f)));
                dst[1] = static_cast<uint8_t>((std::max)(0.0f, (std::min)(255.0f, g * 255.0f + 0.5f)));
                dst[2] = static_cast<uint8_t>((std::max)(0.0f, (std::min)(255.0f, b * 255.0f + 0.5f)));
                dst[3] = static_cast<uint8_t>((std::max)(0.0f, (std::min)(255.0f, a * 255.0f + 0.5f)));

                dst += 4;
            }
        }

        cpuBitmap->Unmap();
        LogToFlutterConsole(L"Copied pixels out and unmapped");

        return true;
    }

    WcgImagePlugin::WcgImagePlugin(flutter::TextureRegistrar* registrar)
            : texture_registrar_(registrar) {}

    WcgImagePlugin::~WcgImagePlugin() {
        if (texture_id_ >= 0)
            texture_registrar_->UnregisterTexture(texture_id_);
    }

    void WcgImagePlugin::RegisterWithRegistrar(
            flutter::PluginRegistrarWindows* registrar) {

        CoInitializeEx(nullptr, COINIT_MULTITHREADED);
        auto channel =
                std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
                        registrar->messenger(),
                                "wcg_image",
                                &flutter::StandardMethodCodec::GetInstance());

        auto plugin =
                std::make_unique<WcgImagePlugin>(
                        registrar->texture_registrar());

        channel->SetMethodCallHandler(
                [plugin_ptr = plugin.get()]
                        (const auto& call, auto result) {
                    plugin_ptr->HandleMethodCall(call, std::move(result));
                });

        registrar->AddPlugin(std::move(plugin));
    }

    void WcgImagePlugin::HandleMethodCall(const flutter::MethodCall<flutter::EncodableValue>& call,std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

        if (call.method_name() == "createTexture") {

            auto args =std::get<flutter::EncodableMap>(*call.arguments());

            std::string utf8 = std::get<std::string>(args[flutter::EncodableValue("path")]);

            int size_needed = MultiByteToWideChar(
                    CP_UTF8, 0,
                    utf8.c_str(),
                    (int)utf8.size(),
                    NULL, 0);

            std::wstring path(size_needed, 0);

            MultiByteToWideChar(
                    CP_UTF8, 0,
                    utf8.c_str(),
                    (int)utf8.size(),
                    &path[0],
                    size_needed);

            LogToFlutterConsole(L"-----------------");
            wprintf(L"%s\n", path.c_str());
            LogToFlutterConsole(L"-----------------");

            if (!LoadColorManagedImage(path,pixels_,width_,height_)) {
                result->Error("load_failed");
                return;
            }

            pixel_buffer_.width = width_;
            pixel_buffer_.height = height_;
            pixel_buffer_.buffer = pixels_.data();

            pixel_texture_ =
                    std::make_unique<flutter::PixelBufferTexture>(
                            [this](size_t, size_t)
                                    -> const FlutterDesktopPixelBuffer* {
                                return &pixel_buffer_;
                            });

            texture_variant_ =
                    std::make_unique<flutter::TextureVariant>(
                            *pixel_texture_);

            texture_id_ =
                    texture_registrar_->RegisterTexture(
                            texture_variant_.get());

            texture_registrar_->MarkTextureFrameAvailable(texture_id_);

            result->Success(flutter::EncodableMap{
                    {flutter::EncodableValue("id"),
                            flutter::EncodableValue(texture_id_)},
                    {flutter::EncodableValue("width"),
                            flutter::EncodableValue((int)width_)},
                    {flutter::EncodableValue("height"),
                            flutter::EncodableValue((int)height_)}
            });
        }
    }
} // namespace wcg_image
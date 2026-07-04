#ifndef RUNNER_WIN32_WINDOW_H_
#define RUNNER_WIN32_WINDOW_H_

#include <windows.h>

// DirectX headers
#include <dxgi1_6.h>
#include <d3d11_4.h>

// WRL for ComPtr - this must come after windows.h
#include <wrl/client.h>

// Standard library
#include <functional>
#include <memory>
#include <string>

using Microsoft::WRL::ComPtr;

// A class abstraction for a high DPI-aware Win32 Window. Intended to be
// inherited from by classes that wish to specialize with custom
// rendering and input handling
class Win32Window {
public:
    struct Point {
        unsigned int x;
        unsigned int y;
        Point(unsigned int x, unsigned int y) : x(x), y(y) {}
    };

    struct Size {
        unsigned int width;
        unsigned int height;
        Size(unsigned int width, unsigned int height)
                : width(width), height(height) {}
    };

    Win32Window();
    virtual ~Win32Window();

    bool Create(const std::wstring& title, const Point& origin, const Size& size);
    bool Show();
    void Destroy();
    void SetChildContent(HWND content);
    HWND GetHandle();
    void SetQuitOnClose(bool quit_on_close);
    RECT GetClientArea();

    // Wide gamut / HDR support
    bool EnableWideGamutSwapChain();
    IDXGISwapChain1* GetSwapChain() const { return swap_chain_.Get(); }
    ID3D11Device* GetD3DDevice() const { return d3d_device_.Get(); }

protected:
    virtual LRESULT MessageHandler(HWND window,
                                   UINT const message,
                                   WPARAM const wparam,
                                   LPARAM const lparam) noexcept;

    virtual bool OnCreate();
    virtual void OnDestroy();

private:
    friend class WindowClassRegistrar;

    static LRESULT CALLBACK WndProc(HWND const window,
    UINT const message,
            WPARAM const wparam,
    LPARAM const lparam) noexcept;

    static Win32Window* GetThisFromHandle(HWND const window) noexcept;
    static void UpdateTheme(HWND const window);

    bool quit_on_close_ = false;
    HWND window_handle_ = nullptr;
    HWND child_content_ = nullptr;

    // DirectX resources
    ComPtr<ID3D11Device> d3d_device_;
    ComPtr<ID3D11DeviceContext> d3d_context_;
    ComPtr<IDXGISwapChain1> swap_chain_;

    bool CreateD3D11SwapChain(HWND hwnd);
    void CleanupD3D();
};

#endif  // RUNNER_WIN32_WINDOW_H_
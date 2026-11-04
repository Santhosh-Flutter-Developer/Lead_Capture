#include "flutter_window.h"

#include <optional>
#include <windows.h>

#include "flutter/generated_plugin_registrant.h"
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

/// Check VC++ Runtime via Registry
bool IsVCRuntimeInstalled() {
  HKEY hKey;
  DWORD installed = 0;
  DWORD size = sizeof(DWORD);

  const wchar_t* subKey =
      L"SOFTWARE\\Microsoft\\VisualStudio\\14.0\\VC\\Runtimes\\x64";

  if (RegOpenKeyExW(
          HKEY_LOCAL_MACHINE,
          subKey,
          0,
          KEY_READ | KEY_WOW64_64KEY,
          &hKey) != ERROR_SUCCESS) {
    return false;
  }

  if (RegQueryValueExW(
          hKey,
          L"Installed",
          nullptr,
          nullptr,
          reinterpret_cast<LPBYTE>(&installed),
          &size) != ERROR_SUCCESS) {
    RegCloseKey(hKey);
    return false;
  }

  RegCloseKey(hKey);
  return installed == 1;
}

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  // MUST be first
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // Create Flutter controller ONCE
  flutter_controller_ =
      std::make_unique<flutter::FlutterViewController>(
          frame.right - frame.left,
          frame.bottom - frame.top,
          project_);

  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }

  // Register MethodChannel HERE
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "runtime.check",
          &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

        if (call.method_name() == "isVCRuntimeInstalled") {
          bool installed = IsVCRuntimeInstalled();
          result->Success(flutter::EncodableValue(installed));
        } else {
          result->NotImplemented();
        }
      });

  // Register plugins
  RegisterPlugins(flutter_controller_->engine());

  // Attach Flutter view
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([this]() {
    this->Show();
  });

  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  flutter_controller_ = nullptr;
  Win32Window::OnDestroy();
}

LRESULT FlutterWindow::MessageHandler(HWND hwnd,
                                     UINT const message,
                                     WPARAM const wparam,
                                     LPARAM const lparam) noexcept {
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(
            hwnd, message, wparam, lparam);
    if (result) {
      return *result;
    }
  }

  if (message == WM_FONTCHANGE) {
    flutter_controller_->engine()->ReloadSystemFonts();
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

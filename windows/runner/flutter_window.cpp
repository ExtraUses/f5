#include "flutter_window.h"

#include <flutter/standard_method_codec.h>

#include <optional>

#include "flutter/generated_plugin_registrant.h"

namespace {
constexpr UINT_PTR kShowFallbackTimer = 1;
constexpr UINT kShowFallbackMs = 4000;
}

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  window_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "streak/window",
          &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    const auto* on = std::get_if<bool>(call.arguments());
    if (call.method_name() != "fullscreen" || on == nullptr) {
      result->NotImplemented();
      return;
    }
    SetFullscreen(*on);
    result->Success();
  });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    KillTimer(this->GetHandle(), kShowFallbackTimer);
    this->Show();
  });

  SetTimer(GetHandle(), kShowFallbackTimer, kShowFallbackMs, nullptr);

  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::SetFullscreen(bool on) {
  HWND hwnd = GetHandle();
  if (on == fullscreen_ || hwnd == nullptr) {
    return;
  }
  fullscreen_ = on;
  if (on) {
    windowed_style_ = GetWindowLong(hwnd, GWL_STYLE);
    GetWindowPlacement(hwnd, &windowed_placement_);
    MONITORINFO monitor = {sizeof(monitor)};
    GetMonitorInfo(MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST), &monitor);
    const RECT& area = monitor.rcMonitor;
    SetWindowLong(hwnd, GWL_STYLE, windowed_style_ & ~WS_OVERLAPPEDWINDOW);
    SetWindowPos(hwnd, HWND_TOP, area.left, area.top, area.right - area.left,
                 area.bottom - area.top, SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
    return;
  }
  SetWindowLong(hwnd, GWL_STYLE, windowed_style_);
  SetWindowPlacement(hwnd, &windowed_placement_);
  SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOOWNERZORDER |
                   SWP_FRAMECHANGED);
}

void FlutterWindow::OnDestroy() {
  window_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    case WM_TIMER:
      if (wparam == kShowFallbackTimer) {
        KillTimer(hwnd, kShowFallbackTimer);
        Show();
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

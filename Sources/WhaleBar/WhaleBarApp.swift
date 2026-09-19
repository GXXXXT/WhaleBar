import AppKit
import SwiftUI
import WhaleBarKit

@main
struct WhaleBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            PanelView()
                .environment(AppServices.shared.appState)
                .environment(AppServices.shared.settings)
        } label: {
            StatusLabelView()
                .environment(AppServices.shared.appState)
                .environment(AppServices.shared.settings)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(AppServices.shared.appState)
                .environment(AppServices.shared.settings)
        }
    }
}

/// 首启动引导：无凭据时自动打开设置窗口
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            AppServices.shared.startEngine()
            if !AppServices.shared.appState.isConfigured {
                try? await Task.sleep(for: .seconds(0.8))
                Self.openSettingsWindow()
            }
        }
    }

    @MainActor
    static func openSettingsWindow() {
        for actionName in ["showSettingsWindow:", "showPreferencesWindow:"] {
            let selector = Selector(actionName)
            if NSApp.responds(to: selector) {
                NSApp.sendAction(selector, to: nil, from: nil)
                break
            }
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}

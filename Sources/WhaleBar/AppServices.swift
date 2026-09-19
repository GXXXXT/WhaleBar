import AppKit
import Foundation
import WhaleBarKit

/// 组合根：组装所有服务（单例，App 生命周期内常驻）
@MainActor
final class AppServices {
    static let shared = AppServices()

    let settings: AppSettings
    let appState: AppState
    let scheduler: RefreshScheduler
    private var workspaceObservers: [NSObjectProtocol] = []

    private init() {
        let settings = AppSettings.standard
        let state = AppState()
        let scheduler = RefreshScheduler(appState: state, intervalProvider: {
            settings.refreshInterval.seconds
        })
        self.settings = settings
        self.appState = state
        self.scheduler = scheduler

        settings.onChange = { [weak scheduler] in
            scheduler?.restart()
        }

        state.loadCache()
        observeSleepWake()
    }

    /// 应用启动完成后调用：立即首刷 + 启动周期调度
    func startEngine() {
        scheduler.start()
    }

    /// 睡眠时暂停刷新，唤醒后立即补偿刷新并重置周期
    private func observeSleepWake() {
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(center.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in AppServices.shared.scheduler.stop() }
        })
        workspaceObservers.append(center.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in AppServices.shared.scheduler.restart() }
        })
    }
}

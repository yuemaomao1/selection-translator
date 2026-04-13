import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginService {
    var isEnabled: Bool {
        guard #available(macOS 13.0, *) else {
            return false
        }

        let status = SMAppService.mainApp.status
        return status == .enabled || status == .requiresApproval
    }

    var statusDescription: String {
        guard #available(macOS 13.0, *) else {
            return "需 macOS 13 或更高版本"
        }

        switch SMAppService.mainApp.status {
        case .enabled:
            return "已启用"
        case .requiresApproval:
            return "已请求，等待用户在系统设置中批准"
        case .notRegistered:
            return "未启用"
        case .notFound:
            return "当前运行形态不是签名后的 app bundle"
        @unknown default:
            return "未知状态"
        }
    }

    func setEnabled(_ enabled: Bool) throws {
        guard #available(macOS 13.0, *) else {
            return
        }

        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    func openSystemSettings() {
        guard #available(macOS 13.0, *) else { return }
        SMAppService.openSystemSettingsLoginItems()
    }
}

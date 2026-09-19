import Foundation
import WhaleBarKit

// MARK: - 检查器基础设施（CLT 环境无 XCTest / Swift Testing，自研轻量断言）

final class CheckContext: @unchecked Sendable {
    static let shared = CheckContext()

    private(set) var passed = 0
    private(set) var failures: [String] = []

    func recordPass(_ name: String) {
        passed += 1
        print("    ✅ \(name)")
    }

    func recordFailure(_ name: String, _ detail: String) {
        failures.append("\(name) — \(detail)")
        print("    ❌ \(name) — \(detail)")
    }

    var summaryLine: String { "通过 \(passed) · 失败 \(failures.count)" }
}

func check(_ condition: Bool, _ name: String, _ detail: String = "") {
    if condition {
        CheckContext.shared.recordPass(name)
    } else {
        CheckContext.shared.recordFailure(name, detail.isEmpty ? "条件为假" : detail)
    }
}

func checkEqual<T: Equatable>(_ actual: T, _ expected: T, _ name: String) {
    if actual == expected {
        CheckContext.shared.recordPass(name)
    } else {
        CheckContext.shared.recordFailure(name, "实际 \(actual) ≠ 期望 \(expected)")
    }
}

func checkOptionalEqual<T: Equatable>(_ actual: T?, _ expected: T?, _ name: String) {
    if actual == expected {
        CheckContext.shared.recordPass(name)
    } else {
        CheckContext.shared.recordFailure(name, "实际 \(String(describing: actual)) ≠ 期望 \(String(describing: expected))")
    }
}

/// 执行体不抛错即通过
func checkNoThrow(_ name: String, _ body: () async throws -> Void) async {
    do {
        try await body()
        CheckContext.shared.recordPass(name)
    } catch {
        CheckContext.shared.recordFailure(name, "意外抛错: \(error)")
    }
}

/// 执行体抛出指定 AppError 即通过
func checkThrowsAppError(_ name: String, expected: AppError, _ body: () async throws -> Void) async {
    do {
        try await body()
        CheckContext.shared.recordFailure(name, "未抛错，期望 \(expected)")
    } catch {
        if let appError = error as? AppError, appError == expected {
            CheckContext.shared.recordPass(name)
        } else {
            CheckContext.shared.recordFailure(name, "抛错 \(error) ≠ 期望 \(expected)")
        }
    }
}

func suite(_ title: String, _ body: () async -> Void) async {
    print("  ▸ \(title)")
    await body()
}

import Foundation
import WhaleBarKit

@main
struct ChecksMain {
    static func main() async {
        print("== WhaleBarKit 检查 ==")
        await runBalanceChecks()
        await runCacheChecks()
        await runThrottleChecks()

        let context = CheckContext.shared
        print("== 检查完成：\(context.summaryLine) ==")
        for failure in context.failures {
            print("  失败详情：\(failure)")
        }
        exit(context.failures.isEmpty ? 0 : 1)
    }
}

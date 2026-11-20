import XCTest

/// KAN-111: every screen from the design catalog passes Apple's accessibility audit
/// at the largest accessibility text size, in English.
///
/// Runs only when asked, so the screenshot workflow (which runs every UI test) is not blocked:
/// `TEST_RUNNER_A11Y_AUDIT=1 xcodebuild test -scheme Screenshots -only-testing:KinledgerUITests/AccessibilityUITests ...`
@MainActor
final class AccessibilityUITests: XCTestCase {
    private struct Screen {
        let name: String
        var screen: String? = nil
        var flags: [String] = []
    }

    private static let screens: [Screen] = [
        Screen(name: "today", flags: ["-design-tab", "today"]),
        Screen(name: "log", flags: ["-design-tab", "log"]),
        Screen(name: "report", flags: ["-design-tab", "report"]),
        Screen(name: "report-pro", flags: ["-design-tab", "report", "-design-pro"]),
        Screen(name: "me", flags: ["-design-tab", "me"]),
        Screen(name: "today-empty", flags: ["-design-tab", "today", "-design-empty"]),
        Screen(name: "onboarding-who", flags: ["-design-onboarding", "-design-step", "1"]),
        Screen(name: "onboarding-family", flags: ["-design-onboarding", "-design-step", "2"]),
        Screen(name: "quick-log", screen: "quickLog"),
        Screen(name: "entry", screen: "entry"),
        Screen(name: "paywall", screen: "paywall"),
        Screen(name: "tax-export", screen: "taxExport", flags: ["-design-pro"]),
        Screen(name: "trash", screen: "trash"),
        Screen(name: "add-person", screen: "addRecipient"),
    ]

    func testEveryScreenPassesTheAuditAtTheLargestTextSize() throws {
        guard ProcessInfo.processInfo.environment["A11Y_AUDIT"] == "1" else {
            throw XCTSkip("Set TEST_RUNNER_A11Y_AUDIT=1 to run the accessibility audit")
        }
        continueAfterFailure = true
        for item in Self.screens {
            let app = XCUIApplication()
            var args = ["-screenshots", "-design", "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                        "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
            if let screen = item.screen { args += ["-design-screen", screen] }
            app.launchArguments = args + item.flags
            app.launch()
            if item.screen != nil {
                _ = app.descendants(matching: .any).matching(identifier: "design.ready").firstMatch.waitForExistence(timeout: 20)
            } else if item.flags.contains("-design-onboarding") {
                _ = app.buttons["Next"].waitForExistence(timeout: 20) || app.buttons["Start logging"].exists
            } else {
                _ = app.tabBars.firstMatch.waitForExistence(timeout: 20)
            }
            sleep(1)
            XCTContext.runActivity(named: item.name) { _ in
                do {
                    let navBar = app.navigationBars.firstMatch
                    try app.performAccessibilityAudit { issue in
                        if let element = issue.element {
                            // Content under a sheet is dimmed and covered; the audit still sees it.
                            if !element.isHittable { return true }
                            // System bar buttons keep their size; iOS shows them in the large content viewer.
                            if issue.auditType == .dynamicType, navBar.exists, navBar.frame.intersects(element.frame) { return true }
                        }
                        let element = issue.element.map { "\($0.elementType.rawValue) '\($0.label)' id='\($0.identifier)'" } ?? "-"
                        print("==== A11Y \(item.name): \(issue.compactDescription) | \(element)")
                        return false
                    }
                } catch {
                    XCTFail("\(item.name): \(error)")
                }
            }
            app.terminate()
        }
    }
}

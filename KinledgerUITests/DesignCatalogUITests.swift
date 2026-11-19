import XCTest

/// Mockups of every screen, state and popup: design/<version>/screens.
/// Each picture is a separate launch with `-design-screen` (see Kinledger/App/DesignGallery.swift),
/// in light and dark. Runs only when DESIGN_DIR is set (the Design screens workflow);
/// skipped in normal test runs.
@MainActor
final class DesignCatalogUITests: XCTestCase {
    private struct Shot {
        let name: String
        var screen: String? = nil
        var flags: [String] = []
    }

    private static let shots: [Shot] = [
        // Tabs, free
        Shot(name: "01-today", flags: ["-design-tab", "today"]),
        Shot(name: "02-log", flags: ["-design-tab", "log"]),
        Shot(name: "03-report", flags: ["-design-tab", "report"]),
        Shot(name: "04-me", flags: ["-design-tab", "me"]),
        // Tabs with Pro
        Shot(name: "05-report-pro", flags: ["-design-tab", "report", "-design-pro"]),
        Shot(name: "06-me-pro", flags: ["-design-tab", "me", "-design-pro"]),
        // Empty states
        Shot(name: "07-today-empty", flags: ["-design-tab", "today", "-design-empty"]),
        Shot(name: "08-log-empty", flags: ["-design-tab", "log", "-design-empty"]),
        Shot(name: "09-report-empty", flags: ["-design-tab", "report", "-design-empty"]),
        // First launch
        Shot(name: "10-onboarding-who", flags: ["-design-onboarding", "-design-step", "1"]),
        Shot(name: "11-onboarding-family", flags: ["-design-onboarding", "-design-step", "2"]),
        // Storage problem banner
        Shot(name: "12-storage-problem", flags: ["-design-tab", "today", "-design-problem"]),
        // Quick log
        Shot(name: "13-quick-log", screen: "quickLog"),
        Shot(name: "14-quick-log-large-amount", screen: "quickLog", flags: ["-design-amount", "4280"]),
        Shot(name: "15-quick-log-edit", screen: "quickLogEdit"),
        // Entry
        Shot(name: "16-entry", screen: "entry"),
        // Pro
        Shot(name: "17-paywall", screen: "paywall"),
        // Me
        Shot(name: "18-tax-export", screen: "taxExport", flags: ["-design-pro"]),
        Shot(name: "19-trash", screen: "trash"),
        Shot(name: "20-add-person", screen: "addRecipient"),
        Shot(name: "21-restore-backup", screen: "restore"),
        Shot(name: "22-delete-account", screen: "deleteAccount"),
    ]

    private static var outputDir: URL? {
        guard let path = ProcessInfo.processInfo.environment["DESIGN_DIR"], !path.isEmpty else { return nil }
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testLight() throws {
        try run(dark: false)
    }

    func testDark() throws {
        try run(dark: true)
    }

    private func run(dark: Bool) throws {
        guard let dir = Self.outputDir else {
            throw XCTSkip("DESIGN_DIR is not set: design screenshots are taken only by the Design screens workflow")
        }
        continueAfterFailure = true
        var missing: [String] = []
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for shot in Self.shots {
            let app = XCUIApplication()
            var args = ["-screenshots", "-design", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
            if dark { args.append("-design-dark") }
            if let screen = shot.screen { args += ["-design-screen", screen] }
            app.launchArguments = args + shot.flags
            app.launch()

            let ready: Bool
            if shot.screen != nil {
                ready = app.descendants(matching: .any).matching(identifier: "design.ready").firstMatch.waitForExistence(timeout: 20)
            } else if shot.flags.contains("-design-onboarding") {
                ready = app.buttons["Next"].waitForExistence(timeout: 20) || app.buttons["Start logging"].exists
            } else {
                ready = app.tabBars.firstMatch.waitForExistence(timeout: 20)
            }
            if !ready { missing.append(shot.name) }
            // Let animations finish.
            sleep(2)
            let theme = dark ? "dark" : "light"
            if springboard.alerts.firstMatch.exists {
                // A system permission prompt is a state of the screen too.
                try? XCUIScreen.main.screenshot().pngRepresentation
                    .write(to: dir.appendingPathComponent("\(shot.name)-permission-\(theme).png"))
                allowSystemAlerts(springboard)
                sleep(2)
            }
            try? XCUIScreen.main.screenshot().pngRepresentation
                .write(to: dir.appendingPathComponent("\(shot.name)-\(theme).png"))
            app.terminate()
            allowSystemAlerts(springboard)
        }
        let note = missing.isEmpty ? "all screens shown" : "not confirmed: " + missing.joined(separator: ", ")
        try? note.write(to: dir.appendingPathComponent("report-\(dark ? "dark" : "light").txt"), atomically: true, encoding: .utf8)
        print("==== DESIGN \(dark ? "dark" : "light"): \(note)")
    }

    /// Answers system permission prompts over the app.
    private func allowSystemAlerts(_ springboard: XCUIApplication) {
        for _ in 0..<4 {
            let alert = springboard.alerts.firstMatch
            guard alert.waitForExistence(timeout: 1) else { return }
            let button = ["Allow", "OK"].lazy.map { alert.buttons[$0] }.first { $0.exists }
                ?? alert.buttons.element(boundBy: alert.buttons.count - 1)
            button.tap()
            sleep(1)
        }
    }
}

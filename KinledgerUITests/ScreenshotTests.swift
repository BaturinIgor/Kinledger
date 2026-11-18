import XCTest

/// Takes the App Store screenshots. Run by .github/workflows/screenshots.yml once per language:
/// SHOT_LANG (an iOS language code) and SHOT_LOCALE come in as TEST_RUNNER_ variables,
/// and SCREENSHOT_DIR is where the PNG files go.
final class ScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testStoreScreenshots() throws {
        let env = ProcessInfo.processInfo.environment
        let language = env["SHOT_LANG"] ?? "en"
        let locale = env["SHOT_LOCALE"] ?? "en_US"
        let folder = URL(fileURLWithPath: env["SCREENSHOT_DIR"] ?? NSTemporaryDirectory())

        let app = XCUIApplication()
        app.launchArguments += ["-screenshots", "-AppleLanguages", "(\(language))", "-AppleLocale", locale]
        app.launch()

        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 20))

        func shot(_ name: String) throws {
            sleep(1)
            let png = XCUIScreen.main.screenshot().pngRepresentation
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try png.write(to: folder.appending(path: "\(language)-\(name).png"))
            let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
            attachment.name = "\(language)-\(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }

        // Tabs, in order: Today, Log, +, Report, Me.
        try shot("1-today")

        tabs.buttons.element(boundBy: 2).tap()
        sleep(1)
        try shot("2-quick-log")
        app.swipeDown(velocity: .fast)
        sleep(1)

        tabs.buttons.element(boundBy: 3).tap()
        try shot("3-report")

        tabs.buttons.element(boundBy: 1).tap()
        try shot("4-log")

        // The newest entry, with its history and the time it was logged.
        let firstEntry = app.cells.element(boundBy: 1)
        if firstEntry.waitForExistence(timeout: 3) {
            firstEntry.tap()
            try shot("5-entry")
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }

        tabs.buttons.element(boundBy: 4).tap()
        try shot("6-me")
    }
}

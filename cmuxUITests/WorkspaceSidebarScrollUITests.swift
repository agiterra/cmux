import Foundation
import XCTest

final class WorkspaceSidebarScrollUITests: XCTestCase {
    private let topTitlebarWorkspaceClearance: CGFloat = 32
    private let maxSidebarOverflowWorkspaceCount = 80
    private var notificationTriggerPath = ""
    private var notificationStatePath = ""
    private var rowHeightProbePath = ""
    private var temporaryDirectoryPath = ""
    private var launchTag = ""

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        let token = UUID().uuidString
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("cmux-ui-test-sidebar-height-\(token)", isDirectory: true)
        try? FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        temporaryDirectoryPath = temporaryDirectory.path
        notificationTriggerPath = temporaryDirectory.appendingPathComponent("trigger").path
        notificationStatePath = temporaryDirectory.appendingPathComponent("state.json").path
        rowHeightProbePath = temporaryDirectory.appendingPathComponent("row.json").path
        launchTag = "ui-sidebar-\(UUID().uuidString.prefix(8))"
        try? FileManager.default.removeItem(atPath: notificationTriggerPath)
        try? FileManager.default.removeItem(atPath: notificationStatePath)
        try? FileManager.default.removeItem(atPath: rowHeightProbePath)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: notificationTriggerPath)
        try? FileManager.default.removeItem(atPath: notificationStatePath)
        try? FileManager.default.removeItem(atPath: rowHeightProbePath)
        if !temporaryDirectoryPath.isEmpty {
            try? FileManager.default.removeItem(atPath: temporaryDirectoryPath)
        }
        super.tearDown()
    }

    func testWorkspaceSelectionKeepsSidebarRowVisible() {
        let app = XCUIApplication()
        configureLaunch(app)
        launchAndEnsureRunning(app)
        XCTAssertTrue(waitForWindowCount(atLeast: 1, app: app, timeout: 8.0), "Expected a main window")
        XCTAssertTrue(
            waitForWorkspaceRowHittable(index: 1, count: 1, app: app, timeout: 8.0),
            "Expected the initial workspace row to be visible"
        )

        let workspaceCount = 20
        for expectedCount in 2...workspaceCount {
            app.typeKey("n", modifierFlags: [.command])
            XCTAssertTrue(
                waitForWorkspaceRowHittable(index: expectedCount, count: expectedCount, app: app, timeout: 6.0),
                "Expected the newly selected workspace \(expectedCount) to be visible"
            )
        }

        XCTAssertTrue(
            waitForWorkspaceRowHittable(index: workspaceCount, count: workspaceCount, app: app, timeout: 6.0),
            "Expected the newly selected bottom workspace to be visible"
        )

        app.typeKey("1", modifierFlags: [.command])
        XCTAssertTrue(
            waitForWorkspaceRowHittable(index: 1, count: workspaceCount, app: app, timeout: 6.0),
            "Expected Cmd+1 to scroll the first workspace back into view"
        )
        XCTAssertTrue(
            waitForWorkspaceRowClearsTitlebar(index: 1, count: workspaceCount, app: app, timeout: 6.0),
            "Expected Cmd+1 to keep the first workspace below the titlebar controls"
        )
    }

    func testCommandPaletteMoveWorkspaceToTopKeepsMovedWorkspaceVisible() {
        let app = XCUIApplication()
        configureLaunch(app)
        launchAndEnsureRunning(app)
        XCTAssertTrue(waitForWindowCount(atLeast: 1, app: app, timeout: 8.0), "Expected a main window")
        XCTAssertTrue(
            waitForWorkspaceRowHittable(index: 1, count: 1, app: app, timeout: 8.0),
            "Expected the initial workspace row to be visible"
        )

        let workspaceCount = 20
        for expectedCount in 2...workspaceCount {
            app.typeKey("n", modifierFlags: [.command])
            XCTAssertTrue(
                waitForWorkspaceRowHittable(index: expectedCount, count: expectedCount, app: app, timeout: 6.0),
                "Expected the newly selected workspace \(expectedCount) to be visible"
            )
        }

        runCommandPaletteMoveToTop(app: app)

        XCTAssertTrue(
            waitForWorkspaceRowHittable(index: 1, count: workspaceCount, app: app, timeout: 6.0),
            "Expected Cmd+Shift+P Move to Top to scroll the moved workspace back into view"
        )
    }

    func testSidebarScrollerVisibilityFollowsWorkspaceOverflow() {
        let app = XCUIApplication()
        configureLaunch(app)
        launchAndEnsureRunning(app)
        XCTAssertTrue(waitForWindowCount(atLeast: 1, app: app, timeout: 8.0), "Expected a main window")
        XCTAssertTrue(
            waitForWorkspaceRowHittable(index: 1, count: 1, app: app, timeout: 8.0),
            "Expected the initial workspace row to be visible"
        )

        let sidebar = app.descendants(matching: .any)["Sidebar"].firstMatch
        XCTAssertTrue(sidebar.waitForExistence(timeout: 5.0), "Expected the workspace sidebar to exist")
        XCTAssertTrue(
            waitForSidebarVerticalScrollerHidden(app: app, sidebar: sidebar, timeout: 4.0),
            "Expected the sidebar scroller to hide when the workspace content fits"
        )

        let overflowProbeStartCount = sidebarOverflowProbeStartCount(app: app, sidebar: sidebar)
        var overflowReached = false
        for expectedCount in 2...maxSidebarOverflowWorkspaceCount {
            app.typeKey("n", modifierFlags: [.command])
            XCTAssertTrue(
                waitForWorkspaceRowHittable(index: expectedCount, count: expectedCount, app: app, timeout: 6.0),
                "Expected the newly selected workspace \(expectedCount) to be visible"
            )

            guard expectedCount >= overflowProbeStartCount else { continue }
            if revealSidebarVerticalScroller(app: app, sidebar: sidebar, timeout: 1.0) {
                overflowReached = true
                break
            }
        }

        XCTAssertTrue(
            overflowReached,
            "Expected the sidebar scroller to appear before creating \(maxSidebarOverflowWorkspaceCount) workspaces"
        )
    }

    func testCompactWorkspaceRowHeightStaysStableWhenNotificationAppears() throws {
        let app = XCUIApplication()
        configureLaunch(app)
        configureCompactSidebarLaunch(app)
        configureSidebarHeightNotificationLaunch(app)
        launchAndEnsureRunning(app)
        XCTAssertTrue(waitForWindowCount(atLeast: 1, app: app, timeout: 8.0), "Expected a main window")
        XCTAssertTrue(
            waitForNotificationStateValue(key: "ready", value: "1", timeout: 8.0),
            "Expected the sidebar row height notification test trigger to become ready"
        )

        let row = workspaceRow(index: 1, count: 1, app: app)
        XCTAssertTrue(row.waitForExistence(timeout: 8.0), "Expected the initial workspace row")
        let baselineHeight = row.frame.height
        let baselineProbe = try XCTUnwrap(
            waitForSidebarHeightProbe(unreadCount: 0, timeout: 4.0),
            "Expected baseline row height probe data"
        )
        XCTAssertEqual(
            baselineProbe.height,
            baselineHeight,
            accuracy: 0.25,
            "Expected the row height probe to match the accessibility row height before notification"
        )

        try triggerSidebarHeightNotification()
        let notificationProbe = try XCTUnwrap(
            waitForSidebarHeightProbe(unreadCount: 1, timeout: 8.0),
            "Expected row height probe data after notification"
        )
        XCTAssertTrue(
            waitForRowHeight(row, matching: notificationProbe.height, timeout: 2.0),
            "Expected the accessibility row height to reflect the post-notification layout"
        )
        XCTAssertTrue(row.exists, "Expected workspace row to remain visible after notification")
        XCTAssertEqual(
            notificationProbe.height,
            baselineHeight,
            accuracy: 0.25,
            "Compact sidebar workspace row layout must not grow when the unread notification badge appears"
        )
        XCTAssertEqual(
            row.frame.height,
            baselineHeight,
            accuracy: 0.25,
            "Compact sidebar workspace rows must not grow when the unread notification badge appears"
        )
    }

    private func configureLaunch(_ app: XCUIApplication) {
        app.launchArguments += ["-newWorkspacePlacement", "end"]
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["CMUX_UI_TEST_MODE"] = "1"
        app.launchEnvironment["CMUX_TAG"] = launchTag
    }

    private func configureCompactSidebarLaunch(_ app: XCUIApplication) {
        app.launchArguments += [
            "-sidebarHideAllDetails", "true",
            "-sidebarShowWorkspaceDescription", "false",
            "-sidebarShowNotificationMessage", "false",
            "-sidebarShowBranchDirectory", "false",
            "-sidebarShowPullRequest", "false",
            "-sidebarShowSSH", "false",
            "-sidebarShowPorts", "false",
            "-sidebarShowLog", "false",
            "-sidebarShowProgress", "false",
            "-sidebarShowStatusPills", "false"
        ]
    }

    private func configureSidebarHeightNotificationLaunch(_ app: XCUIApplication) {
        app.launchEnvironment["CMUX_UI_TEST_SIDEBAR_ROW_HEIGHT_NOTIFICATION_SETUP"] = "1"
        app.launchEnvironment["CMUX_UI_TEST_SIDEBAR_ROW_HEIGHT_NOTIFICATION_TRIGGER_PATH"] = notificationTriggerPath
        app.launchEnvironment["CMUX_UI_TEST_SIDEBAR_ROW_HEIGHT_NOTIFICATION_STATE_PATH"] = notificationStatePath
        app.launchEnvironment["CMUX_UI_TEST_SIDEBAR_ROW_HEIGHT_PROBE"] = "1"
        app.launchEnvironment["CMUX_UI_TEST_SIDEBAR_ROW_HEIGHT_PROBE_PATH"] = rowHeightProbePath
    }

    private func waitForWorkspaceRowHittable(
        index: Int,
        count: Int,
        app: XCUIApplication,
        timeout: TimeInterval
    ) -> Bool {
        return pollUntil(timeout: timeout) {
            let row = workspaceRow(index: index, count: count, app: app)
            return row.exists && row.isHittable
        }
    }

    private func waitForWorkspaceRowClearsTitlebar(
        index: Int,
        count: Int,
        app: XCUIApplication,
        timeout: TimeInterval
    ) -> Bool {
        pollUntil(timeout: timeout) {
            let row = workspaceRow(index: index, count: count, app: app)
            let window = app.windows.firstMatch
            guard row.exists, row.isHittable, window.exists else { return false }
            return row.frame.minY >= window.frame.minY + topTitlebarWorkspaceClearance
        }
    }

    private func workspaceRow(index: Int, count: Int, app: XCUIApplication) -> XCUIElement {
        let position = "workspace \(index) of \(count)"
        return app.descendants(matching: .other)
            .matching(NSPredicate(format: "label ENDSWITH %@", position))
            .firstMatch
    }

    private func sidebarOverflowProbeStartCount(app: XCUIApplication, sidebar: XCUIElement) -> Int {
        let firstRow = workspaceRow(index: 1, count: 1, app: app)
        guard sidebar.exists, firstRow.exists else { return 8 }

        let rowHeight = max(firstRow.frame.height, 1)
        let visibleRows = Int(ceil(sidebar.frame.height / rowHeight))
        return min(maxSidebarOverflowWorkspaceCount, max(3, visibleRows + 1))
    }

    private func waitForWindowCount(atLeast count: Int, app: XCUIApplication, timeout: TimeInterval) -> Bool {
        pollUntil(timeout: timeout) {
            app.windows.count >= count
        }
    }

    private func waitForSidebarVerticalScrollerHidden(
        app: XCUIApplication,
        sidebar: XCUIElement,
        timeout: TimeInterval
    ) -> Bool {
        pollUntil(timeout: timeout) {
            visibleSidebarVerticalScrollers(app: app, sidebar: sidebar).isEmpty
        }
    }

    private func waitForSidebarVerticalScrollerVisible(
        app: XCUIApplication,
        sidebar: XCUIElement,
        timeout: TimeInterval
    ) -> Bool {
        pollUntil(timeout: timeout) {
            !visibleSidebarVerticalScrollers(app: app, sidebar: sidebar).isEmpty
        }
    }

    private func runCommandPaletteMoveToTop(app: XCUIApplication) {
        let searchField = app.textFields["CommandPaletteSearchField"].firstMatch
        app.typeKey("p", modifierFlags: [.command, .shift])
        XCTAssertTrue(searchField.waitForExistence(timeout: 5.0), "Expected command palette search field")
        searchField.click()
        searchField.typeText("move to top")

        let row = app.descendants(matching: .any)
            .matching(
                NSPredicate(
                    format: "identifier BEGINSWITH %@ AND value == %@",
                    "CommandPaletteResultRow.",
                    "palette.moveWorkspaceToTop"
                )
            )
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5.0), "Expected Move to Top command palette row")
        row.click()
        XCTAssertTrue(
            waitForNonExistence(searchField, timeout: 5.0),
            "Expected command palette to dismiss after Move to Top"
        )
    }

    private func waitForNonExistence(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        pollUntil(timeout: timeout) {
            !element.exists
        }
    }

    private func revealSidebarVerticalScroller(
        app: XCUIApplication,
        sidebar: XCUIElement,
        timeout: TimeInterval
    ) -> Bool {
        sidebar.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).hover()
        if waitForSidebarVerticalScrollerVisible(app: app, sidebar: sidebar, timeout: min(0.25, timeout)) {
            return true
        }
        sidebar.swipeUp()
        return waitForSidebarVerticalScrollerVisible(app: app, sidebar: sidebar, timeout: timeout)
    }

    private func visibleSidebarVerticalScrollers(
        app: XCUIApplication,
        sidebar: XCUIElement
    ) -> [XCUIElement] {
        guard sidebar.exists else { return [] }
        let sidebarFrame = sidebar.frame
        return app.descendants(matching: .scrollBar).allElementsBoundByIndex.filter { scroller in
            guard scroller.exists, scroller.isHittable else { return false }
            let frame = scroller.frame
            guard frame.width > 0, frame.height > frame.width else { return false }
            return frame.midX >= sidebarFrame.minX
                && frame.midX <= sidebarFrame.maxX
                && frame.maxY > sidebarFrame.minY
                && frame.minY < sidebarFrame.maxY
        }
    }

    private func launchAndEnsureRunning(_ app: XCUIApplication) {
        let options = XCTExpectedFailure.Options()
        options.isStrict = false
        XCTExpectFailure("Headless CI may launch the app without foreground activation", options: options) {
            app.launch()
        }
        XCTAssertTrue(
            pollUntil(timeout: 10.0) {
                app.state == .runningForeground || app.state == .runningBackground
            },
            "App failed to launch. state=\(app.state.rawValue)"
        )
    }

    private func triggerSidebarHeightNotification() throws {
        try "notify\n".write(
            to: URL(fileURLWithPath: notificationTriggerPath),
            atomically: false,
            encoding: .utf8
        )
    }

    private func waitForNotificationStateValue(key: String, value: String, timeout: TimeInterval) -> Bool {
        pollUntil(timeout: timeout) {
            self.readStringState(at: self.notificationStatePath)?[key] == value
        }
    }

    private func waitForSidebarHeightProbe(unreadCount: Int, timeout: TimeInterval) -> SidebarHeightProbe? {
        var match: SidebarHeightProbe?
        _ = pollUntil(timeout: timeout) {
            guard let probe = self.readSidebarHeightProbe(), probe.unreadCount == unreadCount else {
                return false
            }
            match = probe
            return true
        }
        return match
    }

    private func waitForRowHeight(_ row: XCUIElement, matching height: CGFloat, timeout: TimeInterval) -> Bool {
        pollUntil(timeout: timeout) {
            row.exists && abs(row.frame.height - height) <= 0.25
        }
    }

    private func readSidebarHeightProbe() -> SidebarHeightProbe? {
        guard let payload = readJSONDictionary(at: rowHeightProbePath),
              let unreadCount = payload["unreadCount"] as? Int,
              let height = payload["height"] as? Double else {
            return nil
        }
        return SidebarHeightProbe(height: CGFloat(height), unreadCount: unreadCount)
    }

    private func readStringState(at path: String) -> [String: String]? {
        guard let payload = readJSONDictionary(at: path) else { return nil }
        return payload.reduce(into: [String: String]()) { result, entry in
            if let value = entry.value as? String {
                result[entry.key] = value
            }
        }
    }

    private func readJSONDictionary(at path: String) -> [String: Any]? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return payload
    }

    private struct SidebarHeightProbe {
        let height: CGFloat
        let unreadCount: Int
    }

    private func pollUntil(
        timeout: TimeInterval,
        interval: TimeInterval = 0.05,
        condition: () -> Bool
    ) -> Bool {
        let start = ProcessInfo.processInfo.systemUptime
        while true {
            if condition() {
                return true
            }
            if ProcessInfo.processInfo.systemUptime - start >= timeout {
                return false
            }
            RunLoop.current.run(until: Date().addingTimeInterval(interval))
        }
    }
}

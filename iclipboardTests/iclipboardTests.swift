//
//  iclipboardTests.swift
//  iclipboardTests
//
//  Created by Yash Paliwal on 12/09/26.
//

import XCTest
@testable import iclipboard

final class iclipboardTests: XCTestCase {

    private var userDefaults: UserDefaults!
    private let suiteName = "testClipboardSuite"

    override func setUpWithError() throws {
        try super.setUpWithError()
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDownWithError() throws {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        try super.tearDownWithError()
    }

    func testClipboardItemModel() throws {
        let id = UUID()
        let timestamp = Date()
        let item1 = ClipboardItem(id: id, text: "Hello", timestamp: timestamp)
        let item2 = ClipboardItem(id: id, text: "Hello", timestamp: timestamp)
        
        XCTAssertEqual(item1, item2)
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(item1)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ClipboardItem.self, from: data)
        XCTAssertEqual(decoded, item1)
    }

    func testIgnoresEmptyAndWhitespaceOnlyStrings() {
        let monitor = ClipboardMonitor(userDefaults: userDefaults)
        monitor.stopMonitoring() // Keep test deterministic
        monitor.clearHistory()

        monitor.processNewText("")
        XCTAssertTrue(monitor.history.isEmpty)

        monitor.processNewText("   ")
        XCTAssertTrue(monitor.history.isEmpty)

        monitor.processNewText("\n\t  \n")
        XCTAssertTrue(monitor.history.isEmpty)
    }

    func testIgnoresDuplicateOfFirstItem() {
        let monitor = ClipboardMonitor(userDefaults: userDefaults)
        monitor.stopMonitoring()
        monitor.clearHistory()

        monitor.processNewText("Item 1")
        XCTAssertEqual(monitor.history.count, 1)
        XCTAssertEqual(monitor.history.first?.text, "Item 1")

        monitor.processNewText("Item 1")
        XCTAssertEqual(monitor.history.count, 1)
    }

    func testRemovesOlderDuplicateAndBringsToTop() {
        let monitor = ClipboardMonitor(userDefaults: userDefaults)
        monitor.stopMonitoring()
        monitor.clearHistory()

        monitor.processNewText("First")
        monitor.processNewText("Second")
        monitor.processNewText("Third")

        XCTAssertEqual(monitor.history.map(\.text), ["Third", "Second", "First"])

        // Re-copy "First", should be removed from end and placed at top (index 0)
        monitor.processNewText("First")
        XCTAssertEqual(monitor.history.map(\.text), ["First", "Third", "Second"])
        XCTAssertEqual(monitor.history.count, 3)
    }

    func testStrictTenItemLimitFIFO() {
        let monitor = ClipboardMonitor(userDefaults: userDefaults)
        monitor.stopMonitoring()
        monitor.clearHistory()

        for i in 1...15 {
            monitor.processNewText("Item \(i)")
        }

        XCTAssertEqual(monitor.history.count, 10)
        XCTAssertEqual(monitor.history.first?.text, "Item 15")
        XCTAssertEqual(monitor.history.last?.text, "Item 6")
    }

    func testPersistenceRoundtrip() throws {
        let monitor1 = ClipboardMonitor(userDefaults: userDefaults)
        monitor1.stopMonitoring()
        monitor1.clearHistory()

        monitor1.processNewText("Saved Item 1")
        monitor1.processNewText("Saved Item 2")

        // Instantiate second monitor using same UserDefaults
        let monitor2 = ClipboardMonitor(userDefaults: userDefaults)
        monitor2.stopMonitoring()

        XCTAssertEqual(monitor2.history.count, 2)
        XCTAssertEqual(monitor2.history[0].text, "Saved Item 2")
        XCTAssertEqual(monitor2.history[1].text, "Saved Item 1")
    }
}

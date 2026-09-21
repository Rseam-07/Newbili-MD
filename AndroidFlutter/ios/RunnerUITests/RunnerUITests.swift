import XCTest

/// Exercises the actual UIKit window rotation, rather than just a Flutter
/// MediaQuery override. The Dart smoke entry point performs the app flow.
final class RunnerUITests: XCTestCase {
  @MainActor
  func testLandscapeLaunch() throws {
    continueAfterFailure = false
    XCUIDevice.shared.orientation = .landscapeLeft
    let app = XCUIApplication(bundleIdentifier: "com.rseam07.newbili.md")
    app.launch()
    XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
    // This is also present in the first-use introduction.
    let ready = app.descendants(matching: .any).matching(
      NSPredicate(format: "label CONTAINS %@ OR label == %@", "首页", "跳过首次使用介绍")
    ).firstMatch
    XCTAssertTrue(ready.waitForExistence(timeout: 30))
    XCTAssertGreaterThan(app.frame.width, app.frame.height)
    let finished = app.descendants(matching: .any).matching(
      NSPredicate(format: "label == %@ OR label == %@", "MD_SMOKE_PASSED", "MD_SMOKE_FAILED")
    ).firstMatch
    XCTAssertTrue(finished.waitForExistence(timeout: 90))
    XCTAssertEqual(finished.label, "MD_SMOKE_PASSED")
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = "iPad landscape launch"
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}

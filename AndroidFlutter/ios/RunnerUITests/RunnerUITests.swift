import XCTest

/// Exercises the actual UIKit window rotation, rather than just a Flutter
/// MediaQuery override. The Dart smoke entry point performs the app flow.
final class RunnerUITests: XCTestCase {
  @MainActor
  func testReportedHotfixes() throws {
    continueAfterFailure = false
    XCUIDevice.shared.orientation = .portrait
    let app = XCUIApplication(bundleIdentifier: "com.rseam07.newbili.md")
    app.launch()
    let challenge = app.descendants(matching: .any).matching(
      NSPredicate(format: "label CONTAINS %@", "请通过以下验证")
    ).firstMatch
    XCTAssertTrue(challenge.waitForExistence(timeout: 20), app.debugDescription)
    let captchaRunning = app.descendants(matching: .any).matching(
      NSPredicate(format: "label CONTAINS %@", "MD_CAPTCHA_RUNNING")
    ).firstMatch
    XCTAssertTrue(captchaRunning.exists, app.debugDescription)
    let captcha = XCTAttachment(screenshot: app.screenshot())
    captcha.name = "Real GeeTest challenge"; captcha.lifetime = .keepAlways; add(captcha)
    let closeCaptcha = app.buttons["关闭验证"]
    XCTAssertTrue(closeCaptcha.exists, app.debugDescription)
    closeCaptcha.tap()
    let finished = app.descendants(matching: .any).matching(NSPredicate(
      format: "label CONTAINS %@ OR label CONTAINS %@", "MD_HOTFIX_PASSED", "MD_HOTFIX_FAILED"
    )).firstMatch
    XCTAssertTrue(finished.waitForExistence(timeout: 80), app.debugDescription)
    XCTAssertTrue(finished.label.contains("MD_HOTFIX_PASSED"), app.debugDescription)
    let invitation = XCTAttachment(screenshot: app.screenshot())
    invitation.name = "Creator web page"; invitation.lifetime = .keepAlways; add(invitation)
  }

  @MainActor
  func testIOSUtilities() throws {
    continueAfterFailure = false
    XCUIDevice.shared.orientation = .landscapeLeft
    let app = XCUIApplication(bundleIdentifier: "com.rseam07.newbili.md")
    app.launch()
    let cancel = app.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", "Cancel", "取消")).firstMatch
    XCTAssertTrue(cancel.waitForExistence(timeout: 45), app.debugDescription)
    let first = XCTAttachment(screenshot: app.screenshot())
    first.name = "Files export before cancellation"; first.lifetime = .keepAlways; add(first)
    cancel.tap()
    let nextExport = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "MD_FEATURE_EXPORT_SAVE")).firstMatch
    XCTAssertTrue(nextExport.waitForExistence(timeout: 10), app.debugDescription)
    let save = app.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", "Export", "导出")).firstMatch
    let fallbackSave = app.buttons.matching(NSPredicate(format: "label IN %@", ["Save", "存储", "保存"])).firstMatch
    // UIDocumentPicker opens at the last writable destination on this test iPad.
    let anySave = app.buttons.matching(NSPredicate(format: "label IN %@", ["Export", "导出", "Save", "存储", "保存"])).firstMatch
    XCTAssertTrue(anySave.waitForExistence(timeout: 15), app.debugDescription)
    let second = XCTAttachment(screenshot: app.screenshot())
    second.name = "Files export destination"; second.lifetime = .keepAlways; add(second)
    let confirm = save.exists ? save : fallbackSave
    XCTAssertTrue(confirm.exists, app.debugDescription)
    if !confirm.isEnabled {
      let local = app.cells.matching(NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@ OR label CONTAINS %@", "On My iPad", "我的 iPad", "我的iPad")).firstMatch
      XCTAssertTrue(local.exists, app.debugDescription)
      local.tap()
    }
    XCTAssertTrue(confirm.isEnabled, app.debugDescription)
    confirm.tap()
    let passed = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "MD_FEATURE_PASSED")).firstMatch
    XCTAssertTrue(passed.waitForExistence(timeout: 20), app.debugDescription)
  }

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

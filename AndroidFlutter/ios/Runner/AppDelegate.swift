import Flutter
import UIKit
import Security
import BackgroundTasks
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var updatesChannel: FlutterMethodChannel?
  private var pendingVideo: [String: Any]?
  private let monitor = MDUpdateMonitor()
  private let taskID = "com.rseam07.newbili.md.refresh"

  override func application(_ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    BGTaskScheduler.shared.register(forTaskWithIdentifier: taskID, using: .main) { [weak self] task in
      guard let self else { task.setTaskCompleted(success: false); return }
      let work = Task { @MainActor in
        do { try await self.monitor.check(manual: false); task.setTaskCompleted(success: true) }
        catch { task.setTaskCompleted(success: false) }
        self.scheduleRefresh()
      }
      task.expirationHandler = { work.cancel() }
    }
    UNUserNotificationCenter.current().delegate = self
    scheduleRefresh()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "NewbiliMD") else { return }
    let vault = FlutterMethodChannel(name: "com.rseam07.newbili/legacy_account", binaryMessenger: registrar.messenger())
    vault.setMethodCallHandler { call, result in
      guard call.method == "accountHiveKey" else { result(FlutterMethodNotImplemented); return }
      do { result(FlutterStandardTypedData(bytes: try MDKeychain.accountKey())) }
      catch { result(FlutterError(code: "secure_storage", message: "无法读取安全账号存储，请解锁设备后重试", details: nil)) }
    }
    let channel = FlutterMethodChannel(name: "com.rseam07.newbili/updates", binaryMessenger: registrar.messenger())
    updatesChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      Task { @MainActor in
        if call.method == "consumeOpenVideo" {
          result(self.pendingVideo); self.pendingVideo = nil; return
        }
        do {
          let value = try await self.monitor.invoke(call.method, call.arguments as? [String: Any] ?? [:])
          self.scheduleRefresh()
          result(value)
        } catch {
          result(FlutterError(code: "updates", message: "更新服务暂时不可用，请重试", details: nil))
        }
      }
    }
  }

  private func scheduleRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: taskID)
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
    // The system chooses the actual execution time; foreground checks also run.
    try? BGTaskScheduler.shared.submit(request)
  }

  override func userNotificationCenter(_ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
    let data = response.notification.request.content.userInfo
    if let bvid = data["bvid"] as? String, MDUpdateMonitor.validBvid(bvid) {
      pendingVideo = ["bvid": bvid, "page": data["page"] as? Int ?? 1]
      updatesChannel?.invokeMethod("openVideo", arguments: pendingVideo)
      completionHandler()
    } else {
      super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
    }
  }
}

private enum MDKeychain {
  private static func query(_ account: String) -> [String: Any] {
    [kSecClass as String: kSecClassGenericPassword,
     kSecAttrService as String: "com.rseam07.newbili.md", kSecAttrAccount as String: account]
  }
  static func read(_ account: String) throws -> Data? {
    var q = query(account); q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
    var item: CFTypeRef?
    let code = SecItemCopyMatching(q as CFDictionary, &item)
    if code == errSecItemNotFound { return nil }
    guard code == errSecSuccess, let data = item as? Data else { throw VaultError.unavailable }
    return data
  }
  static func write(_ account: String, data: Data) throws {
    let q = query(account)
    let code = SecItemUpdate(q as CFDictionary, [kSecValueData as String: data] as CFDictionary)
    if code == errSecItemNotFound {
      var value = q; value[kSecValueData as String] = data
      value[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
      guard SecItemAdd(value as CFDictionary, nil) == errSecSuccess else { throw VaultError.unavailable }
    } else if code != errSecSuccess { throw VaultError.unavailable }
  }
  static func accountKey() throws -> Data {
    if let value = try read("accountHiveKey") {
      guard value.count == 32 else { throw VaultError.unavailable }; return value
    }
    var bytes = [UInt8](repeating: 0, count: 32)
    guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw VaultError.unavailable }
    let value = Data(bytes); try write("accountHiveKey", data: value); return value
  }
  enum VaultError: Error { case unavailable }
}

/// A native monitor avoids starting a second Flutter engine or a second Hive
/// writer for background refresh. Account changes invalidate in-flight results.
@MainActor
private final class MDUpdateMonitor {
  private let session: URLSession = {
    let config = URLSessionConfiguration.ephemeral
    config.httpCookieStorage = nil
    config.httpShouldSetCookies = false
    return URLSession(configuration: config, delegate: MDNoRedirects(), delegateQueue: nil)
  }()
  private let defaults = UserDefaults.standard
  private var store: [String: Any]
  private var generation = 0
  private var checkTask: Task<Void, Error>?
  private var checkID: UUID?
  private let key = "newbili.md.updates.v1"
  init() {
    if let data = UserDefaults.standard.data(forKey: "newbili.md.updates.v1"),
       let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
      store = value
    } else { store = [:] }
  }
  private var tracks: [[String: Any]] { store["tracks"] as? [[String: Any]] ?? [] }
  private var level: String { store["level"] as? String ?? "off" }
  private var mid: Int64 { (store["mid"] as? NSNumber)?.int64Value ?? 0 }
  private var now: Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
  static func validBvid(_ id: String) -> Bool { id.range(of: "^BV[0-9A-Za-z]{10}$", options: .regularExpression) != nil }
  private func save() throws {
    store["revision"] = (store["revision"] as? Int ?? 0) + 1
    defaults.set(try JSONSerialization.data(withJSONObject: store), forKey: key)
  }
  private func state(removed: [String: Any]? = nil) async throws -> String {
    let settings = await UNUserNotificationCenter.current().notificationSettings()
    let permitted = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    var result = store
    result["tracks"] = tracks; result["level"] = level
    result["permission"] = permitted; result["seriesPermission"] = permitted; result["upPermission"] = permitted
    result["loggedIn"] = mid > 0; result["checking"] = checkTask != nil
    result["lastChecked"] = store["lastChecked"] ?? 0
    result["status"] = store["status"] ?? "尚未检查更新"
    result["recent"] = store["recent"] ?? []
    result["revision"] = store["revision"] ?? 0
    if let removed { result["removed"] = removed }
    return String(decoding: try JSONSerialization.data(withJSONObject: result), as: UTF8.self)
  }
  private func decode(_ input: Any?) throws -> [String: Any] {
    guard let string = input as? String, let data = string.data(using: .utf8),
      let value = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw MonitorError.invalid }
    return value
  }
  private func invalidateCheck() {
    generation += 1
    checkTask?.cancel()
    checkTask = nil
    checkID = nil
  }
  private func requireCurrent(_ epoch: Int) throws {
    try Task.checkCancellation()
    guard epoch == generation else { throw CancellationError() }
  }
  func invoke(_ method: String, _ args: [String: Any]) async throws -> String {
    var removed: [String: Any]?
    switch method {
    case "state": break
    case "configure":
      guard let newLevel = args["level"] as? String,
        ["off", "specialOnly", "allFollowing"].contains(newLevel) else { throw MonitorError.invalid }
      let cookie = args["cookie"] as? String ?? ""
      let newMid = newLevel == "off" || cookie.isEmpty ? 0 : (args["mid"] as? NSNumber)?.int64Value ?? 0
      try MDKeychain.write("updateCookie", data: Data((newMid > 0 ? cookie : "").utf8))
      if newLevel != level || newMid != mid {
        invalidateCheck()
        store["baseline"] = false; store["seen"] = []
        if newMid != mid { store["recent"] = []; UNUserNotificationCenter.current().removeAllDeliveredNotifications() }
      }
      store["level"] = newLevel; store["mid"] = newMid; try save()
    case "mark", "restore":
      let data = try decode(args[method == "mark" ? "video" : "snapshot"])
      let item = try snapshot(data, markedAt: method == "mark" ? now : (data["markedAt"] as? NSNumber)?.int64Value ?? now)
      if !tracks.contains(where: { ($0["bvid"] as? String) == (item["bvid"] as? String) }) {
        invalidateCheck()
        store["tracks"] = ([item] + tracks).sorted { ($0["markedAt"] as? Int64 ?? 0) > ($1["markedAt"] as? Int64 ?? 0) }
        store["status"] = method == "mark" ? "已添加追更" : "已恢复追更"; store["lastChecked"] = 0; try save()
      }
    case "unmark":
      guard let bvid = args["bvid"] as? String, Self.validBvid(bvid) else { throw MonitorError.invalid }
      removed = tracks.first { $0["bvid"] as? String == bvid }
      invalidateCheck()
      store["tracks"] = tracks.filter { $0["bvid"] as? String != bvid }
      UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["series.\(bvid)"])
      try save()
    case "check": try await check(manual: args["manual"] as? Bool ?? false)
    default: throw MonitorError.invalid
    }
    return try await state(removed: removed)
  }
  private func snapshot(_ data: [String: Any], markedAt: Int64, checkedAt: Int64? = nil) throws -> [String: Any] {
    guard let bvid = data["bvid"] as? String, Self.validBvid(bvid) else { throw MonitorError.invalid }
    var ids = Set<Int64>()
    let pages: [[String: Any]] = (data["pages"] as? [[String: Any]] ?? []).compactMap { part in
      guard let cid = (part["cid"] as? NSNumber)?.int64Value, cid > 0, ids.insert(cid).inserted else { return nil }
      return ["cid": cid, "page": part["page"] as? Int ?? 1, "title": part["part"] as? String ?? part["title"] as? String ?? ""]
    }.sorted { ($0["page"] as? Int ?? 0) < ($1["page"] as? Int ?? 0) }
    let known = (data["known"] as? [Int64] ?? []) + Array(ids)
    return ["bvid": bvid, "title": data["title"] as? String ?? bvid,
      "cover": data["pic"] as? String ?? data["cover"] as? String ?? "",
      "owner": (data["owner"] as? [String: Any])?["name"] as? String ?? data["owner"] as? String ?? "",
      "pages": pages, "known": Array(Set(known)).prefix(4096).map { $0 }, "markedAt": markedAt,
      "checkedAt": checkedAt ?? (data["checkedAt"] as? NSNumber)?.int64Value ?? 0]
  }
  func check(manual: Bool) async throws {
    if let task = checkTask { try await task.value; return }
    if !manual && now - ((store["lastChecked"] as? NSNumber)?.int64Value ?? 0) < 300_000 { return }
    let id = UUID()
    let task = Task { @MainActor in try await self.performCheck() }
    checkTask = task
    checkID = id
    // An obsolete check must not clear a replacement started after an edit.
    defer { if checkID == id { checkTask = nil; checkID = nil } }
    try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
  }
  private func api(_ path: String, cookie: String = "") async throws -> Any {
    guard let url = URL(string: "https://api.bilibili.com" + path) else { throw MonitorError.invalid }
    var request = URLRequest(url: url, timeoutInterval: 15)
    request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
    request.setValue("https://www.bilibili.com/", forHTTPHeaderField: "Referer")
    if !cookie.isEmpty { request.setValue(cookie, forHTTPHeaderField: "Cookie") }
    let (data, response) = try await session.data(for: request)
    try Task.checkCancellation()
    guard let response = response as? HTTPURLResponse, response.statusCode == 200,
      response.url?.host == "api.bilibili.com", data.count < 2_000_000,
      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      json["code"] as? Int == 0, let value = json["data"] else { throw MonitorError.network }
    return value
  }
  private func performCheck() async throws {
    let epoch = generation, start = Date()
    var checked = 0, failed = 0
    for item in tracks.prefix(20) {
      try requireCurrent(epoch)
      if Date().timeIntervalSince(start) > 50 { break }
      do {
        guard let bvid = item["bvid"] as? String, Self.validBvid(bvid) else { throw MonitorError.invalid }
        guard let data = try await api("/x/web-interface/view?bvid=\(bvid)") as? [String: Any] else { throw MonitorError.invalid }
        try requireCurrent(epoch)
        var updated = try snapshot(data, markedAt: (item["markedAt"] as? NSNumber)?.int64Value ?? now, checkedAt: now)
        let known = Set(item["known"] as? [Int64] ?? [])
        let pages = updated["pages"] as? [[String: Any]] ?? []
        let added = pages.filter { !known.contains(($0["cid"] as? NSNumber)?.int64Value ?? 0) }
        updated["known"] = Array(known.union(updated["known"] as? [Int64] ?? [])).prefix(4096).map { $0 }
        store["tracks"] = tracks.map { $0["bvid"] as? String == bvid ? updated : $0 }; try save()
        if !known.isEmpty, let first = added.first {
          try await notify(id: "series.\(bvid)", title: "追更提醒 · \(updated["title"] as? String ?? bvid)",
            body: "新增 \(added.count) 个分 P", bvid: bvid, page: first["page"] as? Int ?? 1, epoch: epoch)
        }
        checked += 1
      } catch is CancellationError { throw CancellationError() } catch { failed += 1 }
    }
    if level != "off", mid > 0, epoch == generation {
      do {
        let cookie = String(decoding: try MDKeychain.read("updateCookie") ?? Data(), as: UTF8.self)
        var allowed: Set<Int64>?
        if level == "specialOnly" {
          allowed = []
          for page in 1...10 {
            try requireCurrent(epoch)
            guard let list = try await api("/x/relation/tag?tagid=-10&pn=\(page)&ps=50", cookie: cookie) as? [[String: Any]] else { throw MonitorError.invalid }
            try requireCurrent(epoch)
            allowed?.formUnion(list.compactMap { ($0["mid"] as? NSNumber)?.int64Value })
            if list.count < 50 { break }
            if page == 10 { throw MonitorError.invalid }
          }
        }
        guard let feed = try await api("/x/polymer/web-dynamic/v1/feed/all?type=video", cookie: cookie) as? [String: Any], epoch == generation else { return }
        var seen = Set(store["seen"] as? [String] ?? [])
        var latest: [String] = []
        for item in feed["items"] as? [[String: Any]] ?? [] {
          try requireCurrent(epoch)
          guard let id = item["id_str"] as? String, let modules = item["modules"] as? [String: Any],
            let author = modules["module_author"] as? [String: Any],
            let dynamic = modules["module_dynamic"] as? [String: Any], let major = dynamic["major"] as? [String: Any],
            let archive = major["archive"] as? [String: Any], let bvid = archive["bvid"] as? String, Self.validBvid(bvid) else { continue }
          latest.append(id)
          let permitted = allowed == nil || allowed!.contains((author["mid"] as? NSNumber)?.int64Value ?? 0)
          if store["baseline"] as? Bool == true, !seen.contains(id), permitted {
            try await notify(id: "up.\(id)", title: "\(author["name"] as? String ?? "关注的 UP") 更新了", body: archive["title"] as? String ?? "新投稿", bvid: bvid, page: 1, epoch: epoch)
          }
          seen.insert(id)
        }
        guard epoch == generation else { return }
        store["seen"] = Array((latest + Array(seen)).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }.prefix(512))
        store["baseline"] = true; checked += 1
      } catch is CancellationError { throw CancellationError() } catch { failed += 1 }
    }
    try requireCurrent(epoch)
    store["lastChecked"] = now
    store["status"] = failed == 0 ? "已检查 \(checked) 项，更新保留在最近更新中" : "已检查 \(checked) 项，\(failed) 项暂时失败，下次重试"
    try save()
  }
  private func notify(id: String, title: String, body: String, bvid: String, page: Int, epoch: Int) async throws {
    try requireCurrent(epoch)
    let entry: [String: Any] = ["id": id, "title": title, "body": body, "bvid": bvid, "page": page, "time": now]
    let old = (store["recent"] as? [[String: Any]] ?? []).filter { $0["id"] as? String != id }
    store["recent"] = Array(([entry] + old).prefix(50)); try save()
    let content = UNMutableNotificationContent(); content.title = title; content.body = body
    content.sound = .default; content.userInfo = ["bvid": bvid, "page": page]
    // Permission denial must not discard the in-app update history.
    try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    if epoch != generation || Task.isCancelled {
      UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
      UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
      throw CancellationError()
    }
  }
  enum MonitorError: Error { case invalid, network }
}

private final class MDNoRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
  func urlSession(_ session: URLSession, task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
    completionHandler: @escaping (URLRequest?) -> Void) {
    // Do not forward Bilibili credentials to a redirected origin.
    completionHandler(nil)
  }
}

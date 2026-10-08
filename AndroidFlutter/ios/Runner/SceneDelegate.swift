import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

}

/// Geometry belongs to the scene's Flutter view, not UIScreen.main. Resizing or
/// switching displays therefore keeps one engine, navigator and video decoder.
final class MDAdaptiveViewController: FlutterViewController, FlutterStreamHandler {
  private var eventChannel: FlutterEventChannel?
  private var methodChannel: FlutterMethodChannel?
  private var sink: FlutterEventSink?
  private var lastSnapshot: NSDictionary?
  private var publishScheduled = false

  override func viewDidLoad() {
    super.viewDidLoad()
    eventChannel = FlutterEventChannel(name: "com.rseam07.newbili/window_events", binaryMessenger: binaryMessenger)
    eventChannel?.setStreamHandler(self)
    methodChannel = FlutterMethodChannel(name: "com.rseam07.newbili/window", binaryMessenger: binaryMessenger)
    methodChannel?.setMethodCallHandler { [weak self] call, result in
      guard call.method == "getWindow" else { result(FlutterMethodNotImplemented); return }
      result(self?.snapshot())
    }
    #if NEWBILI_DUO_SDK
    if #available(iOS 27.1, *) {
      view.addInteraction(UIHingeInteraction { [weak self] _, _ in
        // Reserved regions supply layout geometry. The angle is deliberately
        // not used to invent a crease or trigger playback/orientation changes.
        self?.schedulePublish()
      })
    }
    #endif
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    schedulePublish()
  }

  override func viewSafeAreaInsetsDidChange() {
    super.viewSafeAreaInsetsDidChange()
    schedulePublish()
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    schedulePublish()
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    lastSnapshot = nil
    publish()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    lastSnapshot = nil
    return nil
  }

  private func schedulePublish() {
    guard sink != nil, !publishScheduled else { return }
    publishScheduled = true
    DispatchQueue.main.async { [weak self] in
      self?.publishScheduled = false
      self?.publish()
    }
  }

  private func snapshot() -> [String: Any] {
    var regions: [[String: Any]] = []
    var edge = "bottom"
    var nativeFoldApi = false
    #if NEWBILI_DUO_SDK
    if #available(iOS 27.1, *) {
      nativeFoldApi = true
      for region in view.reservedRegions(kind: .division, options: .includeInactive) {
        let frame = region.frame
        regions.append(["kind": "division", "active": region.isActive,
          "x": frame.minX, "y": frame.minY, "width": frame.width, "height": frame.height])
      }
      for region in view.reservedRegions(kind: .occlusion) where region.isActive {
        let frame = region.frame
        regions.append(["kind": "occlusion", "active": true,
          "x": frame.minX, "y": frame.minY, "width": frame.width, "height": frame.height])
      }
      switch traitCollection.verticalBarEdge {
      case .leading: edge = "leading"
      case .trailing: edge = "trailing"
      default: break
      }
    }
    #endif
    return ["width": view.bounds.width, "height": view.bounds.height,
      "regularWidth": traitCollection.horizontalSizeClass == .regular,
      "phone": traitCollection.userInterfaceIdiom == .phone,
      "controlEdge": edge, "regions": regions, "nativeFoldApi": nativeFoldApi]
  }

  private func publish() {
    guard let sink else { return }
    let next = snapshot() as NSDictionary
    guard lastSnapshot?.isEqual(next) != true else { return }
    lastSnapshot = next
    sink(next)
  }
}

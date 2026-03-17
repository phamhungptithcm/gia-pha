import Flutter
import SafariServices
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var vnpayChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let engine = engineBridge.pluginRegistry as? FlutterEngine {
      configureVnpayChannel(binaryMessenger: engine.binaryMessenger)
    }
  }

  private func configureVnpayChannel(binaryMessenger: FlutterBinaryMessenger) {
    guard vnpayChannel == nil else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "befam.vnpay/mobile_sdk",
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard call.method == "openCheckout" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let args = call.arguments as? [String: Any],
        let checkoutUrl = args["checkoutUrl"] as? String,
        let url = URL(string: checkoutUrl),
        let scheme = url.scheme,
        (scheme == "https" || scheme == "http")
      else {
        result([
          "status": "failed",
          "message": "Invalid checkout URL",
        ])
        return
      }
      self?.openCheckoutInApp(url: url, result: result)
    }
    vnpayChannel = channel
  }

  private func openCheckoutInApp(url: URL, result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      guard let presenter = self.topMostViewController() else {
        self.openExternally(url: url, result: result)
        return
      }
      let safariController = SFSafariViewController(url: url)
      safariController.dismissButtonStyle = .close
      presenter.present(safariController, animated: true) {
        result(["status": "in_app_browser"])
      }
    }
  }

  private func openExternally(url: URL, result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      UIApplication.shared.open(url, options: [:]) { opened in
        result([
          "status": opened ? "external_browser" : "failed",
          "message": opened ? "Opened externally." : "Cannot open checkout URL.",
        ])
      }
    }
  }

  private func topMostViewController(base: UIViewController? = nil) -> UIViewController? {
    let root: UIViewController? = {
      if let base {
        return base
      }
      let scenes = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
      let keyWindow = scenes
        .flatMap(\.windows)
        .first(where: { $0.isKeyWindow })
      return keyWindow?.rootViewController
    }()

    if let nav = root as? UINavigationController {
      return topMostViewController(base: nav.visibleViewController)
    }
    if let tab = root as? UITabBarController {
      return topMostViewController(base: tab.selectedViewController)
    }
    if let presented = root?.presentedViewController {
      return topMostViewController(base: presented)
    }
    return root
  }
}

import AVFoundation
import Cocoa
import Darwin
import FlutterMacOS
import Speech

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    MacOSTccChannel.register(with: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}

/// macOS Speech/Mic helpers for Smart Search.
///
/// Known Flutter issue (#70374): the *first* TCC prompt can SIGABRT when the
/// app is spawned under an IDE parent that lacks usage-description keys.
///
/// Once the user has already granted Speech + Microphone for this bundle ID,
/// calling Speech APIs is safe even under `flutter run` / Cursor — no relaunch.
///
/// This channel NEVER relaunches, NEVER terminates, NEVER opens another app
/// instance.
enum MacOSTccChannel {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "ghadeer_clinic/macos_tcc",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "isTccSafe":
        // Legacy probe — parent process only. Prefer speechReadyState.
        result(Self.isLaunchServicesAttributed())
      case "speechReadyState":
        result(Self.speechReadyState())
      case "hasUsageDescriptions":
        result(Self.hasRequiredUsageDescriptions())
      case "relaunchIndependent":
        // Permanently disabled.
        NSLog("MacOSTccChannel relaunchIndependent ignored — staying in-process")
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Read-only auth snapshot — never prompts, never crashes.
  ///
  /// Returns a map:
  /// - speech: authorized|denied|restricted|notDetermined
  /// - microphone: authorized|denied|restricted|notDetermined
  /// - usageDescriptionsPresent: Bool
  /// - launchServicesAttributed: Bool
  /// - canInitializeSafely: Bool  — true when initialize/listen will not SIGABRT
  static func speechReadyState() -> [String: Any] {
    let speech = statusName(SFSpeechRecognizer.authorizationStatus())
    let mic = micStatusName(AVCaptureDevice.authorizationStatus(for: .audio))
    let usageOk = hasRequiredUsageDescriptions()
    let launchOk = isLaunchServicesAttributed()
    let bothAuthorized = speech == "authorized" && mic == "authorized"
    // Already granted → safe under IDE. First prompt → only safe when attributed
    // to this app (LaunchServices / launchd parent).
    let canInit = usageOk && (bothAuthorized || launchOk)

    return [
      "speech": speech,
      "microphone": mic,
      "usageDescriptionsPresent": usageOk,
      "launchServicesAttributed": launchOk,
      "canInitializeSafely": canInit,
    ]
  }

  static func hasRequiredUsageDescriptions() -> Bool {
    let info = Bundle.main.infoDictionary
    let mic = info?["NSMicrophoneUsageDescription"] as? String
    let speech = info?["NSSpeechRecognitionUsageDescription"] as? String
    return !(mic ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !(speech ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  static func isLaunchServicesAttributed() -> Bool {
    let parentPid = getppid()
    if parentPid <= 1 {
      return true
    }
    let name = processName(pid: parentPid).lowercased()
    // launchd / loginwindow / open = Launch Services ownership of this .app
    return name.contains("launchd")
      || name.contains("loginwindow")
      || name == "open"
  }

  static func statusName(_ status: SFSpeechRecognizerAuthorizationStatus) -> String {
    switch status {
    case .authorized: return "authorized"
    case .denied: return "denied"
    case .restricted: return "restricted"
    case .notDetermined: return "notDetermined"
    @unknown default: return "notDetermined"
    }
  }

  static func micStatusName(_ status: AVAuthorizationStatus) -> String {
    switch status {
    case .authorized: return "authorized"
    case .denied: return "denied"
    case .restricted: return "restricted"
    case .notDetermined: return "notDetermined"
    @unknown default: return "notDetermined"
    }
  }

  static func processName(pid: pid_t) -> String {
    if let path = NSRunningApplication(processIdentifier: pid)?.executableURL?.lastPathComponent,
       !path.isEmpty {
      return path
    }
    var buffer = [CChar](repeating: 0, count: 1024)
    let len = proc_name(pid, &buffer, UInt32(buffer.count))
    guard len > 0 else { return "" }
    return String(cString: buffer)
  }
}

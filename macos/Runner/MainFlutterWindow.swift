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
    // خلفية النافذة بيضاء — بلا صبغة تركواز من نظام macOS.
    self.backgroundColor = NSColor.white
    flutterViewController.view.appearance = NSAppearance(named: .aqua)

    RegisterGeneratedPlugins(registry: flutterViewController)
    MacOSTccChannel.register(with: flutterViewController.engine.binaryMessenger)
    MacOSArabicTtsChannel.register(with: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}

/// macOS Speech/Mic helpers for Smart Search.
///
/// CRITICAL FIX 3: NEVER launch a second Ghadeer.app instance for mic/speech
/// permission. All prompts and STT stay in the current process.
enum MacOSTccChannel {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "ghadeer_clinic/macos_tcc",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "processId":
        result(Int(getpid()))
      case "isTccSafe":
        result(Self.isLaunchServicesAttributed())
      case "speechReadyState":
        result(Self.speechReadyState())
      case "hasUsageDescriptions":
        result(Self.hasRequiredUsageDescriptions())
      case "requestPermissionsInProcess":
        Self.requestPermissionsInProcess { payload in
          result(payload)
        }
      case "openSystemPrivacySettings":
        result(Self.openSystemPrivacySettings())
      case "openStandaloneForMicGrant", "relaunchIndependent":
        // REMOVED — never spawn a second Ghadeer process.
        NSLog(
          "[PERMISSION] PID=\(getpid()) REJECTED \(call.method) — "
            + "second-app launch disabled"
        )
        result(false)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Read-only auth snapshot — never prompts, never crashes, never launches apps.
  static func speechReadyState() -> [String: Any] {
    let speech = statusName(SFSpeechRecognizer.authorizationStatus())
    let mic = micStatusName(AVCaptureDevice.authorizationStatus(for: .audio))
    let usageOk = hasRequiredUsageDescriptions()
    let launchOk = isLaunchServicesAttributed()
    // TCC يُنسب لـ Bundle.main لهذه العملية (.app)، مو لأب flutter/dart.
    // `flutter run` أبوه dartvm — نسمح إذا كنا داخل Runner.app مع Usage Description.
    let canInit = usageOk && (launchOk || isRunningAsBundledApp())

    NSLog(
      "[PERMISSION] PID=\(getpid()) speechReadyState speech=\(speech) mic=\(mic) "
        + "usageOk=\(usageOk) launchAttr=\(launchOk) bundled=\(isRunningAsBundledApp()) "
        + "canInit=\(canInit)"
    )

    return [
      "speech": speech,
      "microphone": mic,
      "usageDescriptionsPresent": usageOk,
      "launchServicesAttributed": launchOk || isRunningAsBundledApp(),
      "canInitializeSafely": canInit,
      "pid": Int(getpid()),
    ]
  }

  /// طلب صلاحيات الميكروفون والكلام في نفس العملية فقط.
  static func requestPermissionsInProcess(
    completion: @escaping ([String: Any]) -> Void
  ) {
    let pid = Int(getpid())
    NSLog("[PERMISSION] PID=\(pid) requestPermissionsInProcess begin")

    guard hasRequiredUsageDescriptions() else {
      NSLog("[PERMISSION] PID=\(pid) missing usage descriptions")
      completion(speechReadyState())
      return
    }

    // ارفض فقط إذا ما كنا .app حقيقياً (TCC بدون Usage Description → SIGABRT).
    guard isLaunchServicesAttributed() || isRunningAsBundledApp() else {
      NSLog(
        "[PERMISSION] PID=\(pid) requestPermissionsInProcess REFUSED — "
          + "not a bundled app (avoids TCC SIGABRT)"
      )
      completion(speechReadyState())
      return
    }

    func finish() {
      let state = speechReadyState()
      NSLog("[PERMISSION] PID=\(pid) requestPermissionsInProcess done \(state)")
      DispatchQueue.main.async { completion(state) }
    }

    let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    if micStatus == .notDetermined {
      AVCaptureDevice.requestAccess(for: .audio) { _ in
        Self.requestSpeechThen(finish)
      }
    } else {
      requestSpeechThen(finish)
    }
  }

  private static func requestSpeechThen(_ finish: @escaping () -> Void) {
    let speechStatus = SFSpeechRecognizer.authorizationStatus()
    guard speechStatus == .notDetermined else {
      finish()
      return
    }
    // تحت flutter/Xcode الأب ليس launchd: requestAuthorization يسبب SIGABRT.
    // افتح إعدادات النظام بدل الطلب المباشر — المستخدم يفعّل «التعرف على الكلام».
    if !isLaunchServicesAttributed() {
      NSLog(
        "[PERMISSION] PID=\(getpid()) speech notDetermined under IDE host — "
          + "skip requestAuthorization, open System Settings"
      )
      _ = openSystemPrivacySettings()
      finish()
      return
    }
    SFSpeechRecognizer.requestAuthorization { _ in
      finish()
    }
  }

  /// يفتح إعدادات النظام فقط — لا يفتح Ghadeer.app أبداً.
  static func openSystemPrivacySettings() -> Bool {
    let pid = Int(getpid())
    // Speech أولاً — هذا ما كان notDetermined ويسبب الانهيار إن طُلب مباشرة.
    let candidates = [
      "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition",
      "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone",
      "x-apple.systempreferences:com.apple.preference.security",
    ]
    for raw in candidates {
      if let url = URL(string: raw), NSWorkspace.shared.open(url) {
        NSLog("[PERMISSION] PID=\(pid) opened System Settings via \(raw)")
        return true
      }
    }
    if let url = URL(string: "x-apple.systempreferences:") {
      let ok = NSWorkspace.shared.open(url)
      NSLog("[PERMISSION] PID=\(pid) opened System Settings fallback ok=\(ok)")
      return ok
    }
    NSLog("[PERMISSION] PID=\(pid) failed to open System Settings")
    return false
  }

  /// عند الفتح الآمن: اطلب الصلاحيات فورًا إن لم تُحدَّد بعد (نفس العملية).
  /// تحت IDE: لا تطلب Speech (SIGABRT) — الإعدادات فقط عند الحاجة من البحث.
  static func promptPermissionsIfSafeLaunch() {
    NSLog("[APP] PID=\(getpid()) promptPermissionsIfSafeLaunch")
    guard hasRequiredUsageDescriptions() else { return }
    guard isLaunchServicesAttributed() else {
      NSLog(
        "[APP] PID=\(getpid()) skip startup permission prompt — IDE/flutter host"
      )
      return
    }
    guard isRunningAsBundledApp() else { return }

    requestPermissionsInProcess { _ in }
  }

  static func hasRequiredUsageDescriptions() -> Bool {
    let info = Bundle.main.infoDictionary
    let mic = info?["NSMicrophoneUsageDescription"] as? String
    let speech = info?["NSSpeechRecognitionUsageDescription"] as? String
    return !(mic ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !(speech ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  /// Runner يعمل كـ `.app` موقّع — حتى لو الأب `flutter`/`dart` من بيئة التطوير.
  static func isRunningAsBundledApp() -> Bool {
    let path = Bundle.main.bundlePath
    guard path.contains(".app") else { return false }
    guard let bid = Bundle.main.bundleIdentifier, !bid.isEmpty else { return false }
    return hasRequiredUsageDescriptions()
  }

  static func isLaunchServicesAttributed() -> Bool {
    let parentPid = getppid()
    if parentPid <= 1 {
      return true
    }
    let name = processName(pid: parentPid).lowercased()
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

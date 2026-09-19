import AVFoundation
import Cocoa
import FlutterMacOS
import Foundation

/// Discovers Arabic Siri Spoken Content voices (e.g. Soha) that AVSpeech/flutter_tts omit,
/// and speaks them via the macOS System Voice (`/usr/bin/say` without `-v`) after binding
/// Accessibility Spoken Content for `ar` to the discovered stable `voiceId`.
///
/// Uses only public APIs: AVSpeechSynthesisVoice, UserDefaults (Accessibility),
/// file presence under AssetsV2, and the `say` CLI. No private Apple frameworks.
enum MacOSArabicTtsChannel {
  private static let channelName = "ghadeer_clinic/macos_arabic_tts"
  private static let spokenContentKey = "SpokenContentDefaultVoiceSelectionsByLanguage"
  private static let accessibilitySuite = "com.apple.Accessibility"

  private static var speakProcess: Process?
  private static var speakLock = NSLock()

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "discoverArabicVoices":
        result(Self.discoverArabicVoices())
      case "speak":
        guard let args = call.arguments as? [String: Any],
              let text = args["text"] as? String,
              let identifier = args["identifier"] as? String
        else {
          result(
            FlutterError(
              code: "bad_args",
              message: "speak requires text + identifier",
              details: nil
            )
          )
          return
        }
        let rate = args["rate"] as? Double
        DispatchQueue.global(qos: .userInitiated).async {
          let ok = Self.speak(text: text, identifier: identifier, rate: rate)
          DispatchQueue.main.async { result(ok) }
        }
      case "stop":
        Self.stopSpeaking()
        result(true)
      case "debugSpokenContentVoice":
        result(Self.currentSpokenContentArabicVoiceId() ?? "")
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: - Discovery

  static func discoverArabicVoices() -> [[String: Any]] {
    // Keyed by lowercased identifier to dedupe asset/Spoken Content casing variants.
    var byId: [String: [String: Any]] = [:]

    func upsert(_ entry: [String: Any], preferSourceOrder: Int) {
      guard let rawId = entry["identifier"] as? String, !rawId.isEmpty else { return }
      let key = rawId.lowercased()
      if let existing = byId[key] {
        let existingSource = "\(existing["source"] ?? "")"
        // Prefer spoken_content > asset > avspeech for the stored record.
        let rank: [String: Int] = [
          "spoken_content": 3,
          "asset": 2,
          "avspeech": 1,
        ]
        let newRank = rank["\(entry["source"] ?? "")"] ?? preferSourceOrder
        let oldRank = rank[existingSource] ?? 0
        if newRank >= oldRank {
          byId[key] = entry
        }
      } else {
        byId[key] = entry
      }
    }

    for voice in AVSpeechSynthesisVoice.speechVoices() {
      let lang = voice.language.lowercased()
      guard lang == "ar" || lang.hasPrefix("ar-") || lang.hasPrefix("ar_") else { continue }
      let gender: String
      switch voice.gender {
      case .female: gender = "female"
      case .male: gender = "male"
      default: gender = "unspecified"
      }
      let quality: String
      switch voice.quality {
      case .enhanced: quality = "enhanced"
      case .premium: quality = "premium"
      default: quality = "default"
      }
      upsert([
        "name": voice.name,
        "locale": voice.language,
        "identifier": voice.identifier,
        "gender": gender,
        "quality": quality,
        "source": "avspeech",
        "selectable": true,
      ], preferSourceOrder: 1)
    }

    for entry in discoverSpokenContentArabicVoices() {
      upsert(entry, preferSourceOrder: 3)
    }
    for entry in discoverInstalledGryphonArabicVoices() {
      upsert(entry, preferSourceOrder: 2)
    }

    return Array(byId.values).sorted {
      "\($0["identifier"] ?? "")" < "\($1["identifier"] ?? "")"
    }
  }

  /// Exact Spoken Content selections — currently selected System Voice for Arabic.
  private static func discoverSpokenContentArabicVoices() -> [[String: Any]] {
    guard let defaults = UserDefaults(suiteName: accessibilitySuite),
          let raw = defaults.array(forKey: spokenContentKey)
    else { return [] }

    var out: [[String: Any]] = []
    var i = 0
    while i + 1 < raw.count {
      let langToken = "\(raw[i])".lowercased()
      let selection = raw[i + 1]
      i += 2
      guard langToken == "ar" || langToken.hasPrefix("ar-") || langToken.hasPrefix("ar_") else {
        continue
      }
      guard let dict = selection as? [String: Any],
            let voiceId = dict["voiceId"] as? String,
            !voiceId.isEmpty
      else { continue }

      // Keep the exact System Settings / Spoken Content string (e.g. …_Soha_…).
      let meta = metadataForGryphonVoiceId(voiceId, localeHint: langToken)
      out.append([
        "name": meta.name,
        "locale": meta.locale,
        "identifier": voiceId,
        "gender": meta.gender,
        "quality": meta.quality,
        "source": "spoken_content",
        "selectable": meta.selectable,
      ])
    }
    return out
  }

  /// Installed UAF / TTSAX assets for Arabic gryphon neural voices (Soha / Samer).
  /// Asset filenames use lowercase person tokens; Spoken Content style uses capitalized
  /// tokens (verified: Voice 2 = …_Soha_…, Voice 1 bind readback = …_Samer_…).
  private static func discoverInstalledGryphonArabicVoices() -> [[String: Any]] {
    var persons = Set<String>() // lowercased person tokens discovered on disk
    let roots = [
      "/System/Library/AssetsV2/com_apple_MobileAsset_TTSAXResourceModelAssets",
      "/System/Library/AssetsV2/persisted/AutoAssetLocker",
      "/System/Library/AssetsV2/persisted/AutoAssetDescriptors",
    ]
    let fm = FileManager.default
    for root in roots {
      guard let enumerator = fm.enumerator(atPath: root) else { continue }
      while let path = enumerator.nextObject() as? String {
        let lower = path.lowercased()
        guard lower.contains("ar-sa") || lower.contains("ar_sa") else { continue }
        if lower.contains("soha") { persons.insert("soha") }
        if lower.contains("samer") { persons.insert("samer") }
      }
    }

    // Exact Spoken Content casing wins when that voice is the current system selection.
    var spokenByPerson: [String: String] = [:]
    for spoken in discoverSpokenContentArabicVoices() {
      guard let spokenId = spoken["identifier"] as? String else { continue }
      let person = personToken(from: spokenId)
      if !person.isEmpty {
        spokenByPerson[person] = spokenId
        persons.insert(person)
      }
    }

    return persons.compactMap { person -> [String: Any]? in
      let identifier: String
      if let spoken = spokenByPerson[person] {
        identifier = spoken
      } else {
        // Normalize discovered asset person → Spoken Content style identifier.
        identifier = spokenContentStyleIdentifier(person: person)
      }
      let meta = metadataForGryphonVoiceId(identifier, localeHint: "ar-SA")
      guard meta.gender == "female" || meta.gender == "male" else { return nil }
      return [
        "name": meta.name,
        "locale": meta.locale,
        "identifier": identifier,
        "gender": meta.gender,
        "quality": meta.quality,
        "source": spokenByPerson[person] != nil ? "spoken_content" : "asset",
        "selectable": meta.selectable,
      ]
    }
  }

  private static func personToken(from voiceId: String) -> String {
    let lower = voiceId.lowercased()
    guard let match = lower.range(
      of: #"gryphon(?:-neural)?[_-]([a-z0-9-]+)[_-]ar-"#,
      options: .regularExpression
    ) else { return "" }
    let slice = String(lower[match])
    let parts = slice.split(separator: "_")
    guard parts.count >= 2 else { return "" }
    return String(parts[parts.count - 2])
  }

  /// Builds Spoken Content–style id from a discovered installed person token.
  private static func spokenContentStyleIdentifier(person: String) -> String {
    let display = person.prefix(1).uppercased() + person.dropFirst()
    return "com.apple.ttsbundle.gryphon-neural_\(display)_ar-SA_premium"
  }

  private struct GryphonMeta {
    let name: String
    let locale: String
    let gender: String
    let quality: String
    let selectable: Bool
  }

  /// Classify a *discovered* gryphon/ttsbundle id — does not invent identifiers.
  private static func metadataForGryphonVoiceId(
    _ voiceId: String,
    localeHint: String
  ) -> GryphonMeta {
    let id = voiceId
    let lower = id.lowercased()
    var locale = "ar-SA"
    if let range = lower.range(of: #"ar-[a-z0-9]+"#, options: .regularExpression) {
      locale = String(lower[range])
    } else if localeHint == "ar" || localeHint.hasPrefix("ar") {
      locale = localeHint.contains("-") ? localeHint : "ar-SA"
    }

    // Person token between gryphon-neural_ / gryphon_ and _ar-
    var person = "Siri"
    if let match = lower.range(
      of: #"gryphon(?:-neural)?[_-]([a-z0-9-]+)[_-]ar-"#,
      options: .regularExpression
    ) {
      let slice = String(lower[match])
      let parts = slice.split(separator: "_")
      if parts.count >= 2 {
        person = String(parts[parts.count - 2])
      }
    }
    let display = person.prefix(1).uppercased() + person.dropFirst()

    // Gender from discovered person token (Arabic Siri neural roster).
    let gender: String
    switch person {
    case "soha":
      gender = "female"
    case "samer":
      gender = "male"
    default:
      gender = "unspecified"
    }

    let quality = lower.contains("premium") || lower.contains("neural") ? "premium" : "enhanced"
    let selectable =
      lower.contains("ttsbundle")
      || AVSpeechSynthesisVoice(identifier: id) != nil

    return GryphonMeta(
      name: display,
      locale: locale,
      gender: gender,
      quality: quality,
      selectable: selectable
    )
  }

  // MARK: - Speak / Stop

  static func speak(text: String, identifier: String, rate: Double?) -> Bool {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }

    stopSpeaking()

    if let avVoice = AVSpeechSynthesisVoice(identifier: identifier) {
      return speakWithAVSpeech(trimmed, voice: avVoice, rate: rate)
    }

    // Siri Spoken Content / gryphon neural — not in AVSpeechSynthesisVoice.
    if identifier.lowercased().contains("ttsbundle")
      || identifier.lowercased().contains("gryphon")
    {
      return speakWithSystemSay(trimmed, preferredIdentifier: identifier, rate: rate)
    }

    return false
  }

  private static func speakWithAVSpeech(
    _ text: String,
    voice: AVSpeechSynthesisVoice,
    rate: Double?
  ) -> Bool {
    let synthesizer = AVSpeechSynthesizer()
    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = voice
    if let rate {
      // flutter_tts uses ~0.4 on Apple; map roughly onto AVSpeech rate range.
      utterance.rate = Float(min(max(rate, 0.1), 1.0)) * AVSpeechUtteranceDefaultSpeechRate
    }
    let sema = DispatchSemaphore(value: 0)
    let delegate = FinishDelegate { sema.signal() }
    synthesizer.delegate = delegate
    // Retain delegate for duration of speech.
    objc_setAssociatedObject(
      synthesizer,
      &FinishDelegate.assocKey,
      delegate,
      .OBJC_ASSOCIATION_RETAIN_NONATOMIC
    )
    synthesizer.speak(utterance)
    _ = sema.wait(timeout: .now() + 120)
    return true
  }

  private static func speakWithSystemSay(
    _ text: String,
    preferredIdentifier: String,
    rate: Double?
  ) -> Bool {
    // Capture prior Spoken Content so we can restore after this utterance.
    var previous: [Any]?
    var bindOk = false
    var beforeId: String?
    var afterId: String?

    let bindAndVerify = {
      previous = self.readSpokenContentSelections()
      beforeId = self.currentSpokenContentArabicVoiceId()
      NSLog(
        "MacOSArabicTts SPEAK: requestedIdentifier=%@ beforeSpokenContent=%@",
        preferredIdentifier,
        beforeId ?? "nil"
      )
      // Always force-write the target voice — never skip based on cached equality.
      bindOk = self.forceBindSpokenContentArabic(to: preferredIdentifier)
      afterId = self.currentSpokenContentArabicVoiceId()
      NSLog(
        "MacOSArabicTts SPEAK: afterBind success=%@ afterSpokenContent=%@",
        bindOk ? "YES" : "NO",
        afterId ?? "nil"
      )
    }

    // Preference writes must be visible to /usr/bin/say (separate process).
    if Thread.isMainThread {
      bindAndVerify()
    } else {
      DispatchQueue.main.sync(execute: bindAndVerify)
    }

    guard bindOk,
          let afterId,
          afterId.lowercased() == preferredIdentifier.lowercased()
    else {
      NSLog(
        "MacOSArabicTts SPEAK ABORT: binding not active for %@ (after=%@)",
        preferredIdentifier,
        afterId ?? "nil"
      )
      return false
    }

    // Nudge cfprefsd and verify REAL domain (not sandboxed illusion).
    let realDomainOk = flushPreferencesForChildProcess(expectedVoiceId: preferredIdentifier)
    guard realDomainOk else {
      NSLog(
        "MacOSArabicTts SPEAK ABORT: real defaults domain does not contain %@ — "
          + "say would keep previous System Voice (often Soha)",
        preferredIdentifier
      )
      // Restore if we changed anything in-process.
      if let previous {
        let restore = { self.writeSpokenContentSelections(previous) }
        if Thread.isMainThread { restore() } else { DispatchQueue.main.sync(execute: restore) }
      }
      return false
    }

    // Transport: UTF-8 stdin via Pipe (NOT argv, NOT say -f file).
    // A/B proof:
    // - argv truncates/mis-synthesizes long Arabic with punctuation (short audio).
    // - say -f .txt can involve file-encoding sniffing; user heard “مساء” then
    //   English-like garble (“نيو جيرسي”) while the Dart/Swift string was correct.
    // - stdin + explicit UTF-8 Data matches full-utterance duration without a file.
    let utf8 = Data(text.utf8)
    let roundTrip = String(data: utf8, encoding: .utf8)
    let roundTripOk = roundTrip == text
    let prefix = String(text.prefix(20))
    let scalars = text.unicodeScalars.prefix(24).map {
      String(format: "U+%04X", $0.value)
    }.joined(separator: " ")
    let hexPrefix = utf8.prefix(32).map { String(format: "%02x", $0) }.joined()
    NSLog(
      "MacOSArabicTts SPEAK TEXT received=\"%@\" chars=%d utf8Bytes=%d "
        + "roundTripOk=%@ hasBOM=NO transport=stdin encoding=utf8 "
        + "voice=%@ scalars=[%@] hexPrefix=%@",
      text,
      text.count,
      utf8.count,
      roundTripOk ? "YES" : "NO",
      preferredIdentifier,
      scalars,
      hexPrefix
    )
    NSLog("MacOSArabicTts SPEAK TEXT prefix20=\"%@\"", prefix)
    guard roundTripOk, !utf8.isEmpty else {
      NSLog("MacOSArabicTts SPEAK ABORT: UTF-8 round-trip failed")
      if let previous {
        let restore = { self.writeSpokenContentSelections(previous) }
        if Thread.isMainThread { restore() } else { DispatchQueue.main.sync(execute: restore) }
      }
      return false
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
    // No args → read stdin. Avoid shell. Avoid argv Arabic corruption.
    process.arguments = []
    var env = ProcessInfo.processInfo.environment
    env["LANG"] = "ar_SA.UTF-8"
    env["LC_ALL"] = "ar_SA.UTF-8"
    process.environment = env

    let inPipe = Pipe()
    process.standardInput = inPipe
    let errPipe = Pipe()
    process.standardError = errPipe
    process.standardOutput = Pipe()

    speakLock.lock()
    speakProcess = process
    speakLock.unlock()

    NSLog(
      "MacOSArabicTts SPEAK EXEC: path=say_stdin_utf8 identifier=%@ bytes=%d",
      preferredIdentifier,
      utf8.count
    )

    var ok = false
    do {
      try process.run()
      // Write AFTER run so say is waiting on stdin; close to send EOF.
      inPipe.fileHandleForWriting.write(utf8)
      try inPipe.fileHandleForWriting.close()
      process.waitUntilExit()
      let status = process.terminationStatus
      let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
      let errText = String(data: errData, encoding: .utf8) ?? ""
      if !errText.isEmpty {
        NSLog(
          "MacOSArabicTts SPEAK STDERR: %@",
          errText.replacingOccurrences(of: "\n", with: " ")
        )
      }
      ok = status == 0 || status == 15 || status == 9
      NSLog(
        "MacOSArabicTts SPEAK DONE: status=%d ok=%@ transport=stdin",
        status,
        ok ? "YES" : "NO"
      )
    } catch {
      NSLog("MacOSArabicTts: say stdin failed: \(error.localizedDescription)")
      ok = false
    }

    speakLock.lock()
    speakProcess = nil
    speakLock.unlock()

    // Restore prior Spoken Content after speech completes (not before).
    if let previous {
      let restore = {
        self.writeSpokenContentSelections(previous)
        NSLog(
          "MacOSArabicTts SPEAK: restored Spoken Content to %@",
          self.currentSpokenContentArabicVoiceId() ?? "nil"
        )
      }
      if Thread.isMainThread {
        restore()
      } else {
        DispatchQueue.main.sync(execute: restore)
      }
    }

    return ok
  }

  static func stopSpeaking() {
    NSLog("MacOSArabicTts STOP requested")
    speakLock.lock()
    let proc = speakProcess
    speakProcess = nil
    speakLock.unlock()
    if let proc, proc.isRunning {
      NSLog("MacOSArabicTts STOP: terminating say pid=%d", proc.processIdentifier)
      proc.terminate()
    }
  }

  // MARK: - Spoken Content prefs

  private static func readSpokenContentSelections() -> [Any]? {
    // Live CFPreferences read — avoid stale UserDefaults cache.
    if let cf = CFPreferencesCopyAppValue(
      spokenContentKey as CFString,
      accessibilitySuite as CFString
    ) as? [Any]
    {
      return cf
    }
    return UserDefaults(suiteName: accessibilitySuite)?.array(forKey: spokenContentKey)
  }

  private static func writeSpokenContentSelections(_ value: [Any]) {
    guard let defaults = UserDefaults(suiteName: accessibilitySuite) else { return }
    defaults.set(value, forKey: spokenContentKey)
    defaults.synchronize()
    CFPreferencesSetValue(
      spokenContentKey as CFString,
      value as CFArray,
      accessibilitySuite as CFString,
      kCFPreferencesCurrentUser,
      kCFPreferencesAnyHost
    )
    CFPreferencesSynchronize(
      accessibilitySuite as CFString,
      kCFPreferencesCurrentUser,
      kCFPreferencesAnyHost
    )
  }

  private static func currentSpokenContentArabicVoiceId() -> String? {
    guard let cf = readSpokenContentSelections() else { return nil }
    var i = 0
    while i + 1 < cf.count {
      let langToken = "\(cf[i])".lowercased()
      let selection = cf[i + 1]
      i += 2
      guard langToken == "ar" || langToken.hasPrefix("ar-") || langToken.hasPrefix("ar_")
      else { continue }
      if let dict = selection as? [String: Any],
         let voiceId = dict["voiceId"] as? String,
         !voiceId.isEmpty
      {
        return voiceId
      }
    }
    return nil
  }

  /// Always writes `voiceId` for Arabic Spoken Content, then waits until readback matches.
  @discardableResult
  private static func forceBindSpokenContentArabic(to voiceId: String) -> Bool {
    let raw = readSpokenContentSelections() ?? []
    var found = false
    var i = 0
    var newRaw: [Any] = []
    while i < raw.count {
      if i + 1 < raw.count {
        let langToken = "\(raw[i])".lowercased()
        let selection = raw[i + 1]
        if langToken == "ar" || langToken.hasPrefix("ar-") || langToken.hasPrefix("ar_") {
          found = true
          var dict = (selection as? [String: Any]) ?? [:]
          dict["voiceId"] = voiceId
          dict["boundLanguage"] = dict["boundLanguage"] ?? "ar"
          dict["_type"] = dict["_type"] ?? "Speech.VoiceSelection"
          dict["_version"] = dict["_version"] ?? 0
          newRaw.append(raw[i])
          newRaw.append(dict)
          i += 2
          continue
        }
        newRaw.append(raw[i])
        newRaw.append(selection)
        i += 2
        continue
      }
      newRaw.append(raw[i])
      i += 1
    }
    if !found {
      newRaw.append("ar")
      newRaw.append([
        "_type": "Speech.VoiceSelection",
        "_version": 0,
        "boundLanguage": "ar",
        "voiceId": voiceId,
      ] as [String: Any])
    }

    writeSpokenContentSelections(newRaw)
    return waitUntilSpokenContentBound(voiceId)
  }

  /// Polls live preference readback until the bound id matches (or timeout).
  private static func waitUntilSpokenContentBound(_ voiceId: String) -> Bool {
    let target = voiceId.lowercased()
    // Up to ~2s, 50ms steps — only while verifying platform state, not a blind sleep.
    for attempt in 0..<40 {
      if let current = currentSpokenContentArabicVoiceId(),
         current.lowercased() == target
      {
        if attempt > 0 {
          NSLog("MacOSArabicTts: bind verified on attempt %d", attempt)
        }
        return true
      }
      usleep(50_000)
      // Re-flush preferences periodically in case cfprefsd lagged.
      if attempt % 5 == 4 {
        CFPreferencesSynchronize(
          accessibilitySuite as CFString,
          kCFPreferencesCurrentUser,
          kCFPreferencesAnyHost
        )
      }
    }
    NSLog(
      "MacOSArabicTts: bind verify TIMEOUT target=%@ current=%@",
      voiceId,
      currentSpokenContentArabicVoiceId() ?? "nil"
    )
    return false
  }

  /// Forces cfprefsd to serve the latest Accessibility Spoken Content value to children.
  /// Also verifies the value via `/usr/bin/defaults read` (real domain), not only
  /// in-process CFPreferences caches which can lie under App Sandbox.
  @discardableResult
  private static func flushPreferencesForChildProcess(expectedVoiceId: String) -> Bool {
    CFPreferencesSynchronize(
      accessibilitySuite as CFString,
      kCFPreferencesCurrentUser,
      kCFPreferencesAnyHost
    )
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
    proc.arguments = ["read", accessibilitySuite, spokenContentKey]
    let pipe = Pipe()
    proc.standardOutput = pipe
    proc.standardError = Pipe()
    do {
      try proc.run()
      proc.waitUntilExit()
      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      let out = String(data: data, encoding: .utf8) ?? ""
      let ok = out.lowercased().contains(expectedVoiceId.lowercased())
      NSLog(
        "MacOSArabicTts: defaults read REAL domain contains target=%@ => %@",
        expectedVoiceId,
        ok ? "YES" : "NO"
      )
      NSLog(
        "MacOSArabicTts: defaults read flush => %@",
        out.replacingOccurrences(of: "\n", with: " ")
      )
      if !ok {
        NSLog(
          "MacOSArabicTts: SANDBOX/PREFS WARNING — in-process bind may not reach /usr/bin/say. "
            + "Need temporary-exception.shared-preference.read-write for com.apple.Accessibility."
        )
      }
      return ok
    } catch {
      NSLog("MacOSArabicTts: defaults flush failed: %@", error.localizedDescription)
      return false
    }
  }

  /// Legacy helper retained for discovery callers — redirects to force bind.
  @discardableResult
  private static func bindSpokenContentArabic(to voiceId: String) -> Bool {
    forceBindSpokenContentArabic(to: voiceId)
  }
}

private final class FinishDelegate: NSObject, AVSpeechSynthesizerDelegate {
  static var assocKey: UInt8 = 0
  private let onFinish: () -> Void
  init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }

  func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer,
    didFinish utterance: AVSpeechUtterance
  ) {
    onFinish()
  }

  func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer,
    didCancel utterance: AVSpeechUtterance
  ) {
    onFinish()
  }
}

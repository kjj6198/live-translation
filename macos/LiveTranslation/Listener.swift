@preconcurrency import AVFAudio
import AVFoundation
import Speech

/// Turns microphone audio into utterances, each tagged with the language it was spoken in.
/// It reports every change to the current utterance, so subtitles can update while someone talks.
actor Listener {
  /// Both transcribers stop revising their text once the speaker pauses. Mic level is not
  /// used because a quiet or distant voice barely rises above the room noise.
  private static let pauseAfterSentence = Duration.milliseconds(1200)
  /// A pause without closing punctuation is usually mid-sentence, as in "字幕を…起こす".
  /// Ending the utterance there would translate each half on its own.
  private static let pauseMidSentence = Duration.seconds(3)

  let events: AsyncThrowingStream<Heard, any Error>
  private let eventSink: AsyncThrowingStream<Heard, any Error>.Continuation

  private let transcribers: [Language: SpeechTranscriber]
  private let analyzer: SpeechAnalyzer
  private let engine = AVAudioEngine()
  private var utterance = 0
  private var finished: [Language: Transcript] = [:]
  private var volatile: [Language: String] = [:]
  private var lastChange = ContinuousClock.now
  private var tasks: [Task<Void, Never>] = []

  init(languages: [Language]) {
    (events, eventSink) = AsyncThrowingStream.makeStream()
    transcribers = Dictionary(uniqueKeysWithValues: languages.map { language in
      let transcriber = SpeechTranscriber(
        locale: language.locale,
        transcriptionOptions: [],
        reportingOptions: [.volatileResults, .fastResults],
        attributeOptions: [.transcriptionConfidence]
      )
      return (language, transcriber)
    })
    analyzer = SpeechAnalyzer(
      modules: Array(transcribers.values),
      options: .init(priority: .userInitiated, modelRetention: .processLifetime)
    )
  }

  func start() async throws {
    // Without an input device, AVAudioEngine reports a placeholder format and installTap raises.
    guard AVCaptureDevice.default(for: .audio) != nil else { throw ListenerError.noMicrophone }
    guard await AVAudioApplication.requestRecordPermission() else { throw ListenerError.microphoneDenied }
    let modules: [any SpeechModule] = Array(transcribers.values)
    if let request = try await AssetInventory.assetInstallationRequest(supporting: modules) {
      try await request.downloadAndInstall()
    }

    let input = engine.inputNode
    let micFormat = input.outputFormat(forBus: 0)
    guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: modules, considering: micFormat),
          let converter = AVAudioConverter(from: micFormat, to: analyzerFormat)
    else { throw ListenerError.unsupportedMicrophone }
    try await analyzer.prepareToAnalyze(in: analyzerFormat)

    let (audio, audioSink) = AsyncStream<AnalyzerInput>.makeStream()
    try await analyzer.start(inputSequence: audio)

    for (language, transcriber) in transcribers {
      tasks.append(Task { await self.collect(transcriber, as: language) })
    }
    tasks.append(Task { await self.endUtterances() })

    input.installTap(onBus: 0, bufferSize: 4096, format: micFormat) { buffer, _ in
      if let converted = convert(buffer, with: converter) { audioSink.yield(AnalyzerInput(buffer: converted)) }
    }
    try engine.start()
  }

  func stop() async {
    engine.inputNode.removeTap(onBus: 0)
    engine.stop()
    tasks.forEach { $0.cancel() }
    await analyzer.cancelAndFinishNow()
    eventSink.finish()
  }

  private func collect(_ transcriber: SpeechTranscriber, as language: Language) async {
    do {
      for try await result in transcriber.results {
        let text = String(result.text.characters)
        if result.isFinal {
          finished[language, default: Transcript()].text += text
          finished[language, default: Transcript()].confidences += result.text.runs.compactMap(\.transcriptionConfidence)
          volatile[language] = nil
        } else {
          volatile[language] = text
        }
        lastChange = .now
        publish(heardSoFar())
      }
    } catch is CancellationError {
    } catch {
      eventSink.finish(throwing: error)
    }
  }

  private func endUtterances() async {
    while !Task.isCancelled {
      try? await Task.sleep(for: .milliseconds(200))
      let heard = heardSoFar()
      guard let language = detectLanguage(heard), let text = heard[language]?.text else { continue }
      let pause = text.endsSentence ? Self.pauseAfterSentence : Self.pauseMidSentence
      guard ContinuousClock.now - lastChange >= pause else { continue }
      // `finalize` returns after both transcribers have delivered their final results.
      try? await analyzer.finalize(through: nil)
      publish(finished)
      finished = [:]
      volatile = [:]
      utterance += 1
    }
  }

  private func heardSoFar() -> [Language: Transcript] {
    var heard = finished
    for (language, text) in volatile { heard[language, default: Transcript()].text += text }
    return heard
  }

  private func publish(_ transcripts: [Language: Transcript]) {
    guard let language = detectLanguage(transcripts), let text = transcripts[language]?.text else { return }
    eventSink.yield(Heard(utterance: utterance, language: language, text: text.trimmingCharacters(in: .whitespacesAndNewlines)))
  }
}

enum ListenerError: LocalizedError {
  case noMicrophone
  case microphoneDenied
  case unsupportedMicrophone

  var errorDescription: String? {
    switch self {
    case .noMicrophone: "No microphone found. Connect one, such as AirPods, a USB mic, or an iPhone, then start again."
    case .microphoneDenied: "Allow microphone access in System Settings > Privacy & Security > Microphone."
    case .unsupportedMicrophone: "This microphone's audio format is not supported."
    }
  }
}

/// The analyzer does not resample, so each mic buffer is converted to the analyzer's format.
private func convert(_ buffer: AVAudioPCMBuffer, with converter: AVAudioConverter) -> AVAudioPCMBuffer? {
  let ratio = converter.outputFormat.sampleRate / buffer.format.sampleRate
  let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up))
  guard let output = AVAudioPCMBuffer(pcmFormat: converter.outputFormat, frameCapacity: capacity) else { return nil }
  nonisolated(unsafe) var supplied = false
  let status = converter.convert(to: output, error: nil) { _, inputStatus in
    if supplied {
      inputStatus.pointee = .noDataNow
      return nil
    }
    supplied = true
    inputStatus.pointee = .haveData
    return buffer
  }
  return status == .error || output.frameLength == 0 ? nil : output
}

import Observation
import Translation

@MainActor
@Observable
final class Interpreter {
  /// The current sentence and the two before it, so the audience can catch up.
  private static let visibleSentences = 3

  private(set) var status = Status.idle
  /// Recent sentences, oldest first. The last one is the sentence being spoken.
  private(set) var subtitles: [Subtitle] = []
  private(set) var hasHeardSpeech = false

  @ObservationIgnored private var listener: Listener?
  @ObservationIgnored private var session: Task<Void, Never>?
  @ObservationIgnored private let translator = Translator()
  @ObservationIgnored private var translationQueue: [Subtitle] = []
  @ObservationIgnored private var isTranslating = false
  @ObservationIgnored private var clearAfterSilence: Task<Void, Never>?

  var isRunning: Bool { status == .preparing || status == .listening }

  func start(languages: [Language]) {
    guard session == nil else { return }
    session = Task { await run(languages: languages) }
  }

  func stop() async {
    session?.cancel()
    await listener?.stop()
    listener = nil
    session = nil
    subtitles = []
    status = .idle
  }

  private func run(languages: [Language]) async {
    status = .preparing
    subtitles = []
    hasHeardSpeech = false
    let listener = Listener(languages: languages)
    self.listener = listener
    do {
      try await listener.start()
      status = .listening
      for try await heard in listener.events { show(heard) }
    } catch {
      await listener.stop()
      self.listener = nil
      session = nil
      status = .failed(error.localizedDescription)
    }
  }

  private func show(_ heard: Heard) {
    hasHeardSpeech = true
    let sentences = heard.text.sentences
    // The transcriber may revise earlier words, which can merge or drop sentences.
    subtitles.removeAll { $0.id.utterance == heard.utterance && $0.id.sentence >= sentences.count }
    for (index, sentence) in sentences.enumerated() {
      let id = Subtitle.ID(utterance: heard.utterance, sentence: index)
      if let existing = subtitles.firstIndex(where: { $0.id == id }) {
        guard subtitles[existing].original != sentence || subtitles[existing].language != heard.language else { continue }
        subtitles[existing].original = sentence
        subtitles[existing].language = heard.language
        translate(subtitles[existing])
      } else {
        let subtitle = Subtitle(id: id, language: heard.language, original: sentence)
        subtitles.append(subtitle)
        translate(subtitle)
      }
    }
    subtitles = Array(subtitles.suffix(Self.visibleSentences))

    clearAfterSilence?.cancel()
    clearAfterSilence = Task {
      try? await Task.sleep(for: .seconds(5))
      guard !Task.isCancelled else { return }
      subtitles = []
    }
  }

  /// Text arrives faster than it can be translated. Each sentence keeps only its newest text in
  /// the queue, and earlier sentences go first so they end with their final translation.
  private func translate(_ subtitle: Subtitle) {
    if let index = translationQueue.firstIndex(where: { $0.id == subtitle.id }) {
      translationQueue[index] = subtitle
    } else {
      translationQueue.append(subtitle)
    }
    guard !isTranslating else { return }
    isTranslating = true
    Task {
      while !translationQueue.isEmpty {
        let request = translationQueue.removeFirst()
        guard subtitles.contains(where: { $0.id == request.id }) else { continue }
        do {
          let translation = try await translator.translate(request.original, from: request.language)
          if let index = subtitles.firstIndex(where: { $0.id == request.id }) {
            subtitles[index].translation = translation
          }
        } catch TranslationError.notInstalled {
          status = .failed("Install English and Japanese in System Settings > General > Language & Region > Translation Languages.")
        } catch {
          continue
        }
      }
      isTranslating = false
    }
  }
}

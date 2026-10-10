@preconcurrency import Translation

/// Owns the sessions because `TranslationSession` is not `Sendable`.
actor Translator {
  private let sessions = Dictionary(uniqueKeysWithValues: Language.allCases.map { language in
    (language, TranslationSession(installedSource: language.locale.language, target: language.other.locale.language))
  })

  func translate(_ text: String, from language: Language) async throws -> String {
    try await sessions[language]!.translate(text).targetText
  }
}

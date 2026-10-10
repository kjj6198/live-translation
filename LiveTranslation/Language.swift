import Foundation

enum Language: String, CaseIterable, Sendable {
  case english = "en"
  case japanese = "ja"

  var locale: Locale {
    switch self {
    case .english: Locale(identifier: "en_US")
    case .japanese: Locale(identifier: "ja_JP")
    }
  }

  var voiceLanguage: String {
    switch self {
    case .english: "en-US"
    case .japanese: "ja-JP"
    }
  }

  var other: Language {
    switch self {
    case .english: .japanese
    case .japanese: .english
    }
  }

  var label: String {
    switch self {
    case .english: "EN"
    case .japanese: "JA"
    }
  }

  var name: String {
    switch self {
    case .english: "English"
    case .japanese: "Japanese"
    }
  }
}

/// What one transcriber heard during one utterance.
struct Transcript: Sendable {
  var text = ""
  var confidences: [Double] = []

  var meanConfidence: Double {
    confidences.isEmpty ? 0 : confidences.reduce(0, +) / Double(confidences.count)
  }
}

/// Apple's speech models cannot identify the spoken language, so both an English and a
/// Japanese transcriber hear every utterance and this picks the one that understood it.
func detectLanguage(_ transcripts: [Language: Transcript]) -> Language? {
  let heard = transcripts.filter { $0.value.text.unicodeScalars.contains(where: CharacterSet.letters.contains) }
  guard let japanese = heard[.japanese] else { return heard.keys.first }
  guard let english = heard[.english] else { return .japanese }
  // Short English replies such as "Yes" come back from the Japanese model in Latin letters,
  // with a confidence close to the English model's.
  if !japanese.text.containsJapaneseScript { return .english }
  return english.meanConfidence >= japanese.meanConfidence ? .english : .japanese
}

extension String {
  var containsJapaneseScript: Bool {
    unicodeScalars.contains { (0x3040...0x30FF).contains($0.value) || (0x4E00...0x9FFF).contains($0.value) }
  }
}

private let sentenceEnders: Set<Character> = ["。", "？", "！", "?", "!"]

extension String {
  var endsSentence: Bool {
    guard let last = trimmingCharacters(in: .whitespaces).last else { return false }
    return sentenceEnders.contains(last) || last == "."
  }

  /// Splits after sentence-ending punctuation. A period only ends a sentence before a space or
  /// the end of the text, so "3.5" stays whole.
  var sentences: [String] {
    var sentences: [String] = []
    var current = ""
    for (index, character) in zip(indices, self) {
      current.append(character)
      let next = self.index(after: index)
      let endsHere = sentenceEnders.contains(character) || (character == "." && (next == endIndex || self[next].isWhitespace))
      if endsHere {
        sentences.append(current)
        current = ""
      }
    }
    sentences.append(current)
    return sentences
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { $0.unicodeScalars.contains(where: CharacterSet.letters.contains) }
  }
}

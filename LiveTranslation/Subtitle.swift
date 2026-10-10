import SwiftUI

/// What the Listener heard so far in one utterance. Utterances are numbered in order.
struct Heard: Sendable {
  let utterance: Int
  let language: Language
  let text: String
}

/// One sentence of an utterance. Sentences are the unit that gets translated and displayed,
/// so a pause in the middle of a sentence never splits its translation.
struct Subtitle: Identifiable, Equatable {
  struct ID: Hashable {
    let utterance: Int
    let sentence: Int
  }

  let id: ID
  var language: Language
  var original: String
  var translation: String?
}

enum Status: Equatable {
  case idle
  case preparing
  case listening
  case failed(String)
}

struct SubtitleStyle: Codable, Equatable {
  /// `nil` uses the system font.
  var fontFamily: String?
  var fontSize: Double
  var textColor: Color.Resolved
  var backgroundColor: Color.Resolved
  var showsOriginal: Bool

  func font(scale: Double = 1) -> Font {
    let size = fontSize * scale
    guard let fontFamily else { return .system(size: size, weight: .semibold) }
    return .custom(fontFamily, size: size).weight(.semibold)
  }
}

enum StylePreset: String, CaseIterable, Identifiable {
  case classic
  case highContrast
  case light
  case outline

  var id: Self { self }

  var name: String {
    switch self {
    case .classic: "Classic"
    case .highContrast: "High Contrast"
    case .light: "Light"
    case .outline: "Outline"
    }
  }

  var style: SubtitleStyle {
    switch self {
    case .classic:
      SubtitleStyle(fontSize: 40, textColor: .white, backgroundColor: .black(opacity: 0.65), showsOriginal: true)
    case .highContrast:
      SubtitleStyle(fontSize: 44, textColor: Color.Resolved(red: 1, green: 0.84, blue: 0.04), backgroundColor: .black(opacity: 0.9), showsOriginal: false)
    case .light:
      SubtitleStyle(fontSize: 40, textColor: Color.Resolved(red: 0.1, green: 0.1, blue: 0.1), backgroundColor: .white(opacity: 0.9), showsOriginal: true)
    case .outline:
      SubtitleStyle(fontSize: 44, textColor: .white, backgroundColor: .black(opacity: 0), showsOriginal: false)
    }
  }
}

private extension Color.Resolved {
  static let white = Color.Resolved(red: 1, green: 1, blue: 1)
  static func white(opacity: Float) -> Self { Color.Resolved(red: 1, green: 1, blue: 1, opacity: opacity) }
  static func black(opacity: Float) -> Self { Color.Resolved(red: 0, green: 0, blue: 0, opacity: opacity) }
}

/// Persists the subtitle style so every view that reads it updates together.
@MainActor
@Observable
final class SubtitleSettings {
  private static let styleKey = "subtitleStyle"
  private static let spokenLanguageKey = "spokenLanguage"

  var style: SubtitleStyle {
    didSet { UserDefaults.standard.set(try? JSONEncoder().encode(style), forKey: Self.styleKey) }
  }

  /// `nil` means the app works out which language each utterance is in.
  var spokenLanguage: Language? {
    didSet { UserDefaults.standard.set(spokenLanguage?.rawValue, forKey: Self.spokenLanguageKey) }
  }

  var listeningLanguages: [Language] { spokenLanguage.map { [$0] } ?? Language.allCases }

  /// The preset the current style matches, or `nil` after the user customized it.
  var preset: StylePreset? {
    get { StylePreset.allCases.first { $0.style == style } }
    set { if let newValue { style = newValue.style } }
  }

  init() {
    let stored = UserDefaults.standard.data(forKey: Self.styleKey).flatMap { try? JSONDecoder().decode(SubtitleStyle.self, from: $0) }
    style = stored ?? StylePreset.classic.style
    spokenLanguage = UserDefaults.standard.string(forKey: Self.spokenLanguageKey).flatMap(Language.init(rawValue:))
  }
}

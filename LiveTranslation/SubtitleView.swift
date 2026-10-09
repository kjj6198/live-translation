import SwiftUI

struct SubtitleLine: Identifiable, Equatable {
  let id: Subtitle.ID
  var original: String?
  var translation: String
}

struct SubtitleView: View {
  private static let pastScale = 0.75
  private static let pastOpacity = 0.7

  let style: SubtitleStyle
  var past: [SubtitleLine] = []
  let current: SubtitleLine

  var body: some View {
    VStack(spacing: style.fontSize * 0.3) {
      ForEach(past) { line in
        lineView(line, scale: Self.pastScale, lineLimit: 2)
          .opacity(Self.pastOpacity)
      }
      lineView(current, scale: 1, lineLimit: 3)
    }
    .foregroundStyle(Color(style.textColor))
    .multilineTextAlignment(.center)
    .shadow(color: .black.opacity(hasBackground ? 0 : 0.9), radius: 3)
    .padding(.horizontal, style.fontSize * 0.5)
    .padding(.vertical, style.fontSize * 0.25)
    .background(Color(style.backgroundColor), in: .rect(cornerRadius: style.fontSize * 0.3))
  }

  /// Long sentences drop their beginning, so the words being spoken stay visible.
  private func lineView(_ line: SubtitleLine, scale: Double, lineLimit: Int) -> some View {
    VStack(spacing: style.fontSize * scale * 0.15) {
      if style.showsOriginal, let original = line.original {
        Text(original)
          .font(style.font(scale: scale * 0.6))
          .opacity(0.75)
      }
      Text(line.translation)
        .font(style.font(scale: scale))
    }
    .lineLimit(lineLimit)
    .truncationMode(.head)
  }

  private var hasBackground: Bool { style.backgroundColor.opacity > 0.3 }
}

/// Fills the floating panel. Empty areas stay fully transparent, so clicks pass through to the slides.
struct SubtitleOverlay: View {
  let interpreter: Interpreter
  let settings: SubtitleSettings

  var body: some View {
    Group {
      if let current {
        SubtitleView(style: settings.style, past: past, current: current)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    .padding(24)
    .animation(.easeOut(duration: 0.2), value: interpreter.subtitles)
  }

  private static let placeholderID = Subtitle.ID(utterance: -1, sentence: 0)

  private var past: [SubtitleLine] {
    interpreter.subtitles.dropLast().compactMap { subtitle in
      subtitle.translation.map { SubtitleLine(id: subtitle.id, original: subtitle.original, translation: $0) }
    }
  }

  private var current: SubtitleLine? {
    switch interpreter.status {
    case .idle: nil
    case .preparing: SubtitleLine(id: Self.placeholderID, translation: "Loading speech models…")
    case .failed(let message): SubtitleLine(id: Self.placeholderID, translation: message)
    case .listening:
      if let subtitle = interpreter.subtitles.last {
        SubtitleLine(id: subtitle.id, original: subtitle.original, translation: subtitle.translation ?? "…")
      } else if !interpreter.hasHeardSpeech {
        SubtitleLine(id: Self.placeholderID, translation: "Listening… 聞いています…")
      } else {
        nil
      }
    }
  }
}

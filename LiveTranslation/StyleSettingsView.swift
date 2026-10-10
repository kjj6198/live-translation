import AppKit
import SwiftUI

struct StyleSettingsView: View {
  @Bindable var settings: SubtitleSettings
  let onResetPosition: () -> Void

  private let fontFamilies = NSFontManager.shared.availableFontFamilies

  var body: some View {
    Form {
      Section {
        SubtitleView(
          style: settings.style,
          past: [SubtitleLine(id: Subtitle.ID(utterance: 0, sentence: 0), original: "Thank you for coming today.", translation: "本日はお越しいただきありがとうございます。")],
          current: SubtitleLine(id: Subtitle.ID(utterance: 0, sentence: 1), original: "Where is the nearest station?", translation: "一番近い駅はどこですか？")
        )
          .frame(maxWidth: .infinity, minHeight: 140)
          .background(.gray.gradient, in: .rect(cornerRadius: 8))
      }

      Section("Preset") {
        Picker("Preset", selection: $settings.preset) {
          Text("Custom").tag(StylePreset?.none)
          ForEach(StylePreset.allCases) { Text($0.name).tag(StylePreset?.some($0)) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
      }

      Section("Text") {
        Picker("Font", selection: $settings.style.fontFamily) {
          Text("System").tag(String?.none)
          Divider()
          ForEach(fontFamilies, id: \.self) { Text($0).tag(String?.some($0)) }
        }
        LabeledContent("Size") {
          Slider(value: $settings.style.fontSize, in: 18...96, step: 2)
          Text("\(Int(settings.style.fontSize)) pt")
            .monospacedDigit()
            .frame(width: 48, alignment: .trailing)
        }
        ColorPicker("Color", selection: colorBinding(\.textColor), supportsOpacity: false)
        Toggle("Show what was said above the translation", isOn: $settings.style.showsOriginal)
      }

      Section("Background") {
        ColorPicker("Color", selection: colorBinding(\.backgroundColor), supportsOpacity: true)
      }

      Section {
        Button("Move Subtitles Back to the Bottom of the Screen", action: onResetPosition)
      }
    }
    .formStyle(.grouped)
    .frame(width: 480)
    .fixedSize(horizontal: false, vertical: true)
  }

  private func colorBinding(_ keyPath: WritableKeyPath<SubtitleStyle, Color.Resolved>) -> Binding<Color> {
    Binding(
      get: { Color(settings.style[keyPath: keyPath]) },
      set: { settings.style[keyPath: keyPath] = $0.resolve(in: EnvironmentValues()) }
    )
  }
}

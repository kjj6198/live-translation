import AppKit
import SwiftUI

@main
struct LiveTranslationApp: App {
  @NSApplicationDelegateAdaptor private var app: AppDelegate

  var body: some Scene {
    MenuBarExtra {
      MenuContent(interpreter: app.interpreter, settings: app.settings)
    } label: {
      Image(systemName: app.interpreter.isRunning ? "captions.bubble.fill" : "captions.bubble")
    }

    Window("Subtitle Style", id: "style") {
      StyleSettingsView(settings: app.settings) { app.panel?.resetPosition() }
    }
    .windowResizability(.contentSize)
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  let interpreter = Interpreter()
  let settings = SubtitleSettings()
  private(set) var panel: SubtitlePanel?

  func applicationDidFinishLaunching(_ notification: Notification) {
    panel = SubtitlePanel(content: SubtitleOverlay(interpreter: interpreter, settings: settings))
  }
}

private struct MenuContent: View {
  let interpreter: Interpreter
  @Bindable var settings: SubtitleSettings
  @Environment(\.openWindow) private var openWindow

  /// Listening restarts so only the chosen language's transcriber runs.
  private var spokenLanguage: Binding<Language?> {
    Binding(
      get: { settings.spokenLanguage },
      set: { language in
        settings.spokenLanguage = language
        guard interpreter.isRunning else { return }
        Task {
          await interpreter.stop()
          interpreter.start(languages: settings.listeningLanguages)
        }
      }
    )
  }

  var body: some View {
    if interpreter.isRunning {
      Button("Stop Subtitles") { Task { await interpreter.stop() } }
        .keyboardShortcut("s")
    } else {
      Button("Start Subtitles") { interpreter.start(languages: settings.listeningLanguages) }
        .keyboardShortcut("s")
    }
    if case .failed(let message) = interpreter.status {
      Text(message)
    }

    Divider()

    Picker("I'm Speaking", selection: spokenLanguage) {
      Text("Detect Automatically").tag(Language?.none)
      ForEach(Language.allCases, id: \.self) { Text($0.name).tag(Language?.some($0)) }
    }

    Divider()

    Picker("Style", selection: $settings.preset) {
      ForEach(StylePreset.allCases) { Text($0.name).tag(StylePreset?.some($0)) }
    }
    Button("Customize Style…") {
      openWindow(id: "style")
      NSApp.activate()
    }
    .keyboardShortcut(",")

    Divider()

    Button("Quit Live Translation") { NSApp.terminate(nil) }
      .keyboardShortcut("q")
  }
}

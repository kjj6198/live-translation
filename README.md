# Live Translation for macOS

Live subtitles for talks. Speak English and Japanese subtitles appear over your slides. Speak Japanese and English subtitles appear. Everything runs on the Mac with Apple's Speech and Translation frameworks. It needs no API key and no network once the models are installed.

Requires macOS 26.4 or later, Xcode 26, and a microphone. A Mac mini has no built-in one, so connect AirPods, a USB mic, or an iPhone.

## Run

```sh
brew install xcodegen
xcodegen generate
open LiveTranslation.xcodeproj
```

Press Run in Xcode. The app has no window. Use the captions icon in the menu bar.

- **Start Subtitles** (⌘S in the menu) starts listening. The first start downloads the English and Japanese speech models.
- **I'm Speaking** sets the language you talk in. Choose English or Japanese when you know it. That runs one speech model instead of two and avoids wrong guesses. Detect Automatically handles both.
- **Style** switches between the Classic, High Contrast, Light, and Outline presets.
- **Customize Style…** opens a window for font, size, text color, background color, and whether the original sentence shows above the translation. Changes apply at once and are saved.

Drag the subtitle to move it. It floats above other apps, including full-screen slideshows. If it ends up off screen, use "Move Subtitles Back to the Bottom of the Screen" in Customize Style.

If subtitles show a "not installed" message, add English and Japanese in System Settings > General > Language & Region > Translation Languages.

## How it works

- Apple's speech models cannot tell which language is being spoken. In Detect Automatically mode the app runs an English and a Japanese `SpeechTranscriber` on the same audio and keeps the transcript with the higher confidence. If the Japanese transcript has no kana or kanji, it keeps the English one, which covers short replies like "Yes".
- The subtitle updates while you talk. The app translates the newest text as soon as the previous translation finishes, so the translation catches up about once a second.
- A subtitle ends when the transcribers stop revising their text for 1.2 s, or after 6 s of continuous speech so it stays about two lines long. The app then calls `SpeechAnalyzer.finalize(through:)` to get the final text right away. The mic level is not used, because a distant or quiet voice barely rises above the room noise.
- The two previous sentences stay above the current one, smaller and at 0.7 opacity, so the audience can catch up. Each sentence keeps its place in the translation queue, so older ones still get their final translation after you move on.
- Subtitles clear after 5 s of silence.
- The app remembers where you dragged the subtitles and keeps them on the screen you left them on, even if the saved position would fall off screen.

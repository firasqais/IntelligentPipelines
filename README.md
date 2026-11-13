# Intelligence Pipeline

A SwiftUI app that shows how voice-driven AI features were built **before on-device Apple Intelligence**:
four separate stages, wired together by hand.

```
 Audio  →   Speech to text  →   Intent classification  →   Cloud LLM
```

1. **Record**: a spoken question from the microphone, a sample spoken by text-to-speech, or typed text.
2. **Transcribe**: Apple's Speech framework turns the audio into text, on the device.
3. **Classify intent**: a NaturalLanguage-based router decides whether the request needs a large model.
4. **Cloud LLM**: questions are sent over HTTPS to OpenAI, Google Gemini or Anthropic.

It was built as the opening demo for the course *Architecting Apple Intelligence: On-Device AI & Agentic Workflows*,
as a contrast with apps where a single on-device `LanguageModelSession` replaces stages 3 and 4.

---

## Requirements

| | Minimum | Notes |
|---|---|---|
| **Mac** | Apple silicon, macOS 26 | |
| **Xcode** | 26 or later | Tested with Xcode 27 |
| **iOS** | 26.0 or later | The deployment target is iOS 26.0 |
| **Device** | iPhone or iPad running iOS 26 | Recommended for recording. The simulator works for the **Sample** and **Type** inputs |
| **Apple developer account** | Free or paid | Needed to run on a physical device |
| **Internet** | First run, and for the cloud stage | The on-device speech model downloads once; the cloud LLM needs a connection |
| **API key** | Optional | Without one, the cloud stage runs in a clearly labelled **Demo mode** |

### Device settings

- **Microphone**: allow when asked, or turn on in *Settings › Privacy & Security › Microphone › IntelligencePipeline*.
- **Speech Recognition**: allow when asked, or turn on in *Settings › Privacy & Security › Speech Recognition*.
- **Dictation**: turn on in *Settings › General › Keyboard › Enable Dictation*. The older speech engine, used as a fallback, needs it.
- **Language**: English must be available as a device or dictation language. The app prefers Australian English, then US English.

### Frameworks used

All are part of the iOS SDK; there are no third-party packages.

| Framework | Used for |
|---|---|
| SwiftUI | The interface |
| AVFoundation | Recording (`AVAudioEngine`), text-to-speech for the sample (`AVSpeechSynthesizer`), audio conversion |
| Speech | Transcription: `SpeechAnalyzer` with `SpeechTranscriber` or `DictationTranscriber`, falling back to `SFSpeechRecognizer` |
| NaturalLanguage | Sentiment score in the intent router |
| Security | Storing API keys in the Keychain |
| Foundation (`URLSession`) | Calling the cloud LLM |

---

## Getting started

1. Clone the repository and open `IntelligencePipeline.xcodeproj`.
2. Select the **IntelligencePipeline** target › **Signing & Capabilities**, and choose **your own Team**.
   If Xcode reports that the bundle identifier is taken, change `au.edu.uts.IntelligencePipeline` to something unique.
3. Choose an iPhone (a connected device, or a simulator) as the run destination and press **⌘R**.
4. Pick an input at the top of the screen and tap **Run Pipeline**:
   - **Sample**: the app speaks *"What is the weather going to be like in Jakarta tomorrow?"* and processes that audio. No file needed.
   - **Record**: tap **Start Recording**, ask a question (the red level bar should move), then tap **Stop & Run Pipeline**.
   - **Type**: enter a question to test the later stages without audio.

The first transcription may pause for a minute while iOS downloads the English speech model.

---

## Connecting a cloud LLM

No code changes are needed; the key is entered in the app.

1. Get an API key from one provider:

   | Provider | Where to get a key | Default model |
   |---|---|---|
   | Google Gemini | aistudio.google.com › Get API key (has a free tier) | `gemini-2.5-flash` |
   | OpenAI | platform.openai.com › API keys (needs prepaid credit) | `gpt-4o-mini` |
   | Anthropic | console.anthropic.com › API keys (needs prepaid credit) | `claude-haiku-5-5` |

2. In the app, tap the **gear icon**, choose the provider, paste the key, and tap **Save**.
3. Ask a **question** (start with *what, how, who, when* or *why*). Commands such as "Turn on the lights" are handled
   on-device and skip the cloud on purpose.

The key is stored in the device's **Keychain**, never in the source code or in this repository.
Model names change over time; if the cloud stage reports *model not found*, type the current name in the **Model** field.

---

## Step-by-step tutorial

The `Tutorial` folder builds this app from an empty project: **5 tutorials, 24 steps**, with code that updates as you
scroll, app previews, diagrams, quizzes and a project download, in the style of Apple's SwiftUI tutorials.

| How | Use it |
|---|---|
| `Tutorial/IntelligencePipeline Tutorial.html` | Double-click to open in any browser. Works offline and prints to PDF |
| `Tutorial/Preview Tutorial.command` | Double-click to serve the DocC tutorial from your Mac |
| `Tutorial/Export Tutorial.command` | Double-click to make a `.doccarchive` that opens in Xcode |
| `Tutorial/IntelligencePipeline.docc` | The DocC source |

| Chapter | Tutorial | Builds |
|---|---|---|
| Audio In | Capturing Audio | `PipelineStage`, `SampleAudioService`, `AudioRecorderService` |
| Audio In | Speech to Text | `SpeechTranscriberService`: `SFSpeechRecognizer`, then `SpeechAnalyzer`, then the Dictation fallback |
| Deciding and Answering | Routing on the Device | `IntentResult`, `IntentClassifierService` |
| Deciding and Answering | Calling a Cloud LLM | `LLMSettings` with the Keychain, `CloudLLMService`, `SettingsView` |
| Wiring the Pipeline | Running the Pipeline | `PipelineViewModel`, `PipelineStageView`, `ContentView`, and how Foundation Models compares |

Every file the tutorial builds matches this repository exactly.
The app screens in the tutorial are drawn mockups with example answers; to use real screenshots, save them over the
`ip-preview-*.png` files in `Tutorial/IntelligencePipeline.docc/Resources/Images` and regenerate the HTML.

---

## Project structure

| File | What it does |
|---|---|
| `IntelligencePipelineApp.swift` | App entry point |
| `ContentView.swift` | Input picker, the four stages, Run button, final response |
| `PipelineStageView.swift` | One stage row with its status and output |
| `PipelineStage.swift` | The four steps and their status values |
| `PipelineViewModel.swift` | Runs the stages in order and holds the state the UI shows |
| `AudioRecorderService.swift` | Records the microphone with `AVAudioEngine` and reports a live level |
| `SampleAudioService.swift` | Speaks the sample question into an audio file with text-to-speech |
| `SpeechTranscriberService.swift` | Audio → text, trying `SpeechTranscriber`, then `DictationTranscriber`, then `SFSpeechRecognizer` |
| `IntentClassifierService.swift` | Keyword router with a NaturalLanguage sentiment fallback |
| `IntentResult.swift` | The router's label and confidence, and the rule for when to call the cloud |
| `CloudLLMService.swift` | Builds the request and reads the reply for each provider; Demo mode when there's no key |
| `LLMSettings.swift` | Provider, model and Keychain-backed API key |
| `SettingsView.swift` | The settings screen |

---

## Troubleshooting

| What you see | What to do |
|---|---|
| The app builds but doesn't launch | Choose an iPhone run destination. If none is listed, install an iOS runtime in *Xcode › Settings › Components* |
| *Signing for "IntelligencePipeline" requires a development team* | Select your Team in *Signing & Capabilities* (see Getting started) |
| *Microphone access is off for this app* | Turn it on in *Settings › Privacy & Security › Microphone*. iOS only asks once |
| The level bar doesn't move while recording | The microphone isn't receiving sound. On the simulator, pick a Mac microphone in *I/O › Audio Input* |
| *Speech recognition failed* with a list of engines | Check Dictation is on and English is available, connect to the internet for the model download, and try again. The Xcode console shows details on lines starting with `[Speech]` |
| *HTTP 401 / 403* in the Cloud LLM stage | The API key was rejected; check it in Settings |
| *HTTP 404* | The model name is wrong or retired; update it in Settings |
| *HTTP 429* | Rate limit reached, or no credit left on the key |
| Cloud stage shows *[Demo mode]* | No API key is saved for the selected provider |

The Xcode console logs each cloud call on lines starting with `[CloudLLM]`.

---

## Privacy

- Recording, transcription and intent classification happen **on the device**.
- Only the transcribed text is sent to the cloud provider, and only when a key is saved and the router decides a question needs it.
- API keys are kept in the Keychain and are never written to disk in plain text or committed to this repository.

---

## Ideas for extending it

- Replace the keyword router in `IntentClassifierService.swift` with a text classifier trained in Create ML.
- Stream the cloud reply token by token instead of waiting for the whole answer.
- Replace stages 3 and 4 with an on-device `LanguageModelSession` from the Foundation Models framework, and compare.

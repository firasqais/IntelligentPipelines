# Swift Code Guide

@Metadata {
    @TechnologyRoot
}

Every keyword and `@` attribute you meet in the IntelligencePipeline tutorials, explained with the app's own code. This app uses the **older** way of sharing state with SwiftUI, `ObservableObject` and `@Published`, so you'll see it next to the newer `@Observable` used in the other course apps.

Most of the app's ideas meet at the top of `PipelineViewModel.swift`:

```swift
@MainActor                                   // all of its code runs on the main thread, like the UI
class PipelineViewModel: ObservableObject {  // SwiftUI can watch this object
    @Published var isRunning = false         // a change here redraws the views that use it
    private let recorder = AudioRecorderService()   // only the view model can see the services
}
```

The table is the quick index. The sections below explain each item.

| You see | In one line | Section |
| --- | --- | --- |
| `struct` | A value type: copying it makes an independent copy | Types |
| `class` / `final class` | A reference type, shared by everyone holding it; `final` forbids subclasses | Types |
| `enum` with `case done(String)` | A fixed set of cases, some carrying a value | Types |
| `static` | Belongs to the type itself, not to one instance | Types |
| `private` / `private(set)` | Hidden outside the type / readable everywhere, changeable only inside | Access control |
| `ObservableObject` / `@Published` | A class SwiftUI watches / a property that triggers a redraw | SwiftUI state |
| `@StateObject` | The view creates and owns the object, once | SwiftUI state |
| `@State` / `@Environment` | A view's own value / a value SwiftUI provides | SwiftUI state |
| `async` / `await` | A function that can pause; `await` marks where it may | Concurrency |
| `@MainActor` | Runs on the main thread, where all UI updates must happen | Concurrency |
| `Task { }` | Starts async work from ordinary code | Concurrency |
| `withCheckedContinuation` | Turns a callback API into an `async` function | Concurrency |
| `AsyncStream` / `for try await` | A sequence of values that arrive over time | Concurrency |
| `[weak self]` | A closure that doesn't keep its object alive | Closures and memory |
| `throws` / `try` / `catch` | A function that can fail, and how you handle it | Errors |
| `as?` / `[String: Any]` | Try to read a value as a type / a dictionary of anything | Working with JSON |
| `some View`, `@ViewBuilder`, `#Preview` | SwiftUI view syntax | SwiftUI views |
| `guard`, `if let`, `if case`, `??`, `$0` | Everyday Swift shorthand | Everyday syntax |

## Types: struct, class and enum

### struct: a value you copy

```swift
struct IntentResult {
    let label: String       // e.g. "question", "command"
    let confidence: Double  // 0.0 – 1.0

    var requiresCloud: Bool {
        label == "question" || confidence < 0.75
    }
}
```

Assigning a struct makes an independent copy, so data can't change behind your back. `let` properties never change after creation. `requiresCloud` is a **computed property**: it's worked out each time it's read, from the other two.

### class and final class: one shared object

The view model and the services are classes: there's one `AudioRecorderService`, and everyone who holds it holds the *same* one, with the same open microphone. `final class AudioRecorderService` means no other class can inherit from it.

`SampleAudioService` is `final class SampleAudioService: NSObject`. Inheriting from `NSObject` is how older Apple frameworks, written in Objective-C, expect objects to look.

### enum: cases, raw values and associated values

```swift
enum PipelineStep: Int, CaseIterable, Identifiable {
    case record, transcribe, classifyIntent, cloudLLM
    var id: Int { rawValue }
}

enum StageStatus: Equatable {
    case waiting, running, done(String), failed(String)
}
```

`PipelineStep` lists the four stages. `: Int` numbers them 0 to 3 as their `rawValue`, `CaseIterable` provides `PipelineStep.allCases` so the screen can loop over them, and `Identifiable` gives each an `id` for `ForEach`.

`StageStatus` cases can **carry a value**: `.done("question (85%)")` or `.failed("Microphone access is off…")`. These are called associated values; read them back with `if case .done(let s) = self`. `Equatable` lets two statuses be compared with `==`.

`LLMSettings` and `Keychain` are enums with no cases, used as a home for `static` functions. Because they have no cases, nobody can create one by mistake.

### static: belongs to the type

`SampleAudioService.sampleText` is a `static let`: one sample sentence for the whole app, read without creating a service. Inside the type, `Self.sampleText` means the same thing.

## Access control: private and private(set)

```swift
final class AudioRecorderService {
    private let engine = AVAudioEngine()
    private(set) var isRecording = false
}
```

| Keyword | Who can read it | Who can change it |
| --- | --- | --- |
| *(nothing)*, which means `internal` | Any file in the app | Any file, if it's a `var` |
| `private(set) var` | Any file in the app | Only code inside the type |
| `private` | Only code inside the type, in that file | Only code inside the type |

The view model can ask `recorder.isRecording`, but only the recorder can change it, so the two can never disagree. The audio engine is `private`: nothing outside the recorder should touch it.

## SwiftUI state: ObservableObject, @Published and @StateObject

SwiftUI redraws a view when data it reads changes. This app uses the original way to tell it which data that is.

```swift
@MainActor
class PipelineViewModel: ObservableObject {
    @Published var stageStatuses: [PipelineStep: StageStatus] = …
    @Published var finalResponse: String?
}

struct ContentView: View {
    @StateObject private var vm = PipelineViewModel()
    @State private var showsSettings = false
}
```

| You see | What it does |
| --- | --- |
| `ObservableObject` | The class can announce changes to SwiftUI |
| `@Published` | A change to this property makes the views that use it redraw |
| `@StateObject` | The view creates the object once and keeps it while the view exists |
| `@State` | A small value the view owns, such as whether the Settings sheet is open |
| `$vm.source` | A binding: lets the segmented picker read and write `vm.source` |
| `@Environment(\.dismiss)` | The action that closes the Settings sheet |

**Compare with `@Observable`.** The newer `@Observable` macro does the same job with less code: no `@Published` on each property, and views hold it in `@State` instead of `@StateObject`. It also redraws only the views that read the property that changed. TaskSynthesiser, WorkspaceAssistant and AgentPlayground use `@Observable`; this app keeps the older style on purpose, as part of the "classic way".

`withAnimation(.easeInOut(duration: 0.25)) { stageStatuses[step] = status }` animates every view that changes because of that one assignment, which is how each stage row fades between states.

## Concurrency: async, await, @MainActor and Task

### async and await: functions that can pause

```swift
guard await speechService.requestPermission() else { … }
let result = try await speechService.transcribe(audioURL: url)
let response = try await cloudService.complete(prompt: text)
```

Recording, recognising speech and calling a server all take time. `async` marks a function that can pause; `await` marks where it may. While `runPipeline()` waits, the screen keeps drawing, animating and responding. `try await` means the call may pause *and* may throw an error.

### @MainActor and Task

`@MainActor` on the view model makes every property and method run on the main thread, where SwiftUI expects changes. A button's action isn't async, so it starts the work with `Task { await vm.runPipeline() }`.

```swift
recorder.onLevel = { [weak self] level in
    Task { @MainActor in
        guard let self else { return }
        self.micLevel = level
    }
}
```

The recorder reports the microphone level from the **audio thread**, many times a second. `Task { @MainActor in … }` hops back to the main thread before touching `micLevel`, which the screen reads. `await Task.yield()` gives the screen a moment to draw "Running" before a fast stage finishes.

### withCheckedContinuation: callback to async

```swift
await withCheckedContinuation { continuation in
    SFSpeechRecognizer.requestAuthorization { status in
        continuation.resume(returning: status == .authorized)
    }
}
```

Many older APIs report back through a **callback** closure instead of `async`. `withCheckedContinuation` pauses the async function and hands you a `continuation`; calling `continuation.resume(returning:)` from the callback ends the pause with that value. The throwing version, `withCheckedThrowingContinuation`, can also `resume(throwing:)`, which `SampleAudioService` uses when text-to-speech produces no audio. Resume exactly once: never is a hang, twice is a crash.

### AsyncStream and for try await

```swift
let (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()

for try await result in transcriber.results where result.isFinal {
    text += String(result.text.characters)
}
```

An `AsyncStream` is a sequence whose values arrive over time. The app feeds audio buffers into one with `yield(…)` and ends it with `finish()`; `SpeechAnalyzer` reads from it. `for try await` loops over results as they arrive, and `where result.isFinal` skips the provisional guesses.

`defer { … }` runs when a function exits by any path, so clean-up always happens: `defer { isRunning = false }` re-enables the Run button, and `defer { collector.cancel() }` stops the transcription task.

## Closures and memory: [weak self]

```swift
input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
    guard let self else { return }
    try self.file?.write(from: buffer)
}
```

A closure **captures** the values it uses. If an object stores a closure that captures the object itself, each keeps the other alive forever: a memory leak. `[weak self]` captures a reference that doesn't keep the object alive and becomes `nil` when it's gone. `guard let self else { return }` stops early if it is. `_` ignores the closure's second argument, which isn't needed.

## Errors: throws, try and catch

```swift
enum LLMError: LocalizedError {
    case invalidResponse
    case http(status: Int, body: String)
    var errorDescription: String? { … }
}
```

`throws` on a function means it can fail; `throw` reports the failure. The caller marks the call with `try` and handles failures in `do { … } catch { … }`. Conforming to `LocalizedError` with an `errorDescription` makes `error.localizedDescription` show your sentence in the stage row.

| You see | Meaning |
| --- | --- |
| `catch where source == .sample { … }` | Only catches when the input was the sample; other failures fall to the next `catch` |
| `try? FileManager.default.removeItem(at: url)` | Ignore the error; here, the file may simply not exist |
| `if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode)` | Treat any status outside 200–299 as a failure |

## Working with JSON and system APIs

```swift
request.httpBody = try JSONSerialization.data(withJSONObject: body)

let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
let choices = json["choices"] as? [[String: Any]]
return choices?.first?["message"] …
```

Each provider replies in a different JSON shape. `[String: Any]` is a dictionary whose values can be anything; `as? [[String: Any]]` tries to read a value as an array of dictionaries and gives `nil` if it isn't one. `?.` continues only while each step isn't `nil`, so a reply in an unexpected shape ends as `nil` instead of crashing.

| API | Used for |
| --- | --- |
| `URLSession.shared.data(for: request)` | Sends the HTTPS request and waits for the reply |
| `UserDefaults.standard` | Remembers the chosen provider and model |
| `SecItemAdd`, `SecItemCopyMatching` with `kSec…` keys | Saves and reads the API key in the Keychain |
| `NLTagger(tagSchemes: [.sentimentScore])` | Scores a sentence from -1 (negative) to 1 (positive) |
| `AVSpeechSynthesizer`, `AVAudioEngine`, `AVAudioFile` | Speak the sample, record the microphone, write audio files |

`static var provider: LLMProvider { get { … } set { … } }` is a computed property with a **getter and setter**: reading it loads from `UserDefaults`, assigning to it saves.

## SwiftUI view syntax

| You see | Meaning |
| --- | --- |
| `var body: some View` | "One specific view type; the compiler knows which" |
| `@ViewBuilder` | Lets a property or function you write use `if` or `switch` to return different views |
| `ForEach(InputSource.allCases) { … }` | One picker option per input source, told apart by `id` |
| `.sheet(isPresented: $showsSettings)` | Shows Settings while `showsSettings` is true |
| `.onSubmit { Task { await vm.runPipeline() } }` | Runs the pipeline when Return is pressed in the text field |
| `#Preview { ContentView() }` | A preview in Xcode's canvas, not part of the app |

## Everyday Swift syntax

| You see | Meaning |
| --- | --- |
| `String?`, `var transcript: String?` | Optional: a value or `nil` |
| `guard let url = recorder.stop() else { return }` | Unwrap, or leave early; `url` is usable for the rest of the function |
| `if let text { … }` | Shorthand for `if let text = text`: unwrap a value with the same name |
| `if case .done(let s) = self { return s }` | Match one enum case and read its value |
| `a ?? b` | `a` if it isn't `nil`, otherwise `b` |
| `PipelineStep.allCases.map { ($0, .waiting) }` | A closure; `$0` is each stage, and `( , )` makes a pair |
| `sum / Float(buffer.frameLength)` | Converts a number to another numeric type before dividing |
| `0..<Int(buffer.frameLength)` | A range from 0 up to, but not including, the end |
| `"\(Int(intent.confidence * 100))%"` | String interpolation: inserts a value into text |
| `condition ? a : b` | `a` if true, else `b` |
| `// MARK: – Services` | Not code: a heading in Xcode's jump bar |

#if os(iOS)
import Foundation
import Combine
import Speech
import AVFoundation

@MainActor
final class VoiceInputService: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var transcript: String = ""

    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer()
    private var tapInstalled = false

    func requestAuthorization() async -> Bool {
        let auth = await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        return auth == .authorized
    }

    func start() async {
        guard !isRecording else { return }
        guard recognizer?.isAvailable == true else { return }
        do {
            let speechGranted = await requestAuthorization()
            guard speechGranted else { return }

            let micGranted = await requestMicAuthorization()
            guard micGranted else { return }

            try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)

            request = SFSpeechAudioBufferRecognitionRequest()
            request?.shouldReportPartialResults = true

            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.request?.append(buffer)
            }
            tapInstalled = true

            audioEngine.prepare()
            try audioEngine.start()

            guard let request = request else { return }
            recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }
                if let result { self.transcript = result.bestTranscription.formattedString }
                if error != nil || (result?.isFinal ?? false) { self.stopInternal() }
            }
            isRecording = true
        } catch {
            stopInternal()
        }
    }

    func stop() { stopInternal() }

    private func stopInternal() {
        if audioEngine.isRunning { audioEngine.stop() }
        if tapInstalled { audioEngine.inputNode.removeTap(onBus: 0); tapInstalled = false }
        request?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        request = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func reset() {
        stopInternal()
        transcript = ""
    }
}
#else
import Foundation
import Combine

@MainActor
final class VoiceInputService: ObservableObject {
    @Published private(set) var transcript: String = ""
    @Published private(set) var isRecording: Bool = false

    func start() async {}
    func stop() async {}
    func reset() {}
}
#endif

#if os(iOS)
private extension VoiceInputService {
    func requestMicAuthorization() async -> Bool {
        await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
    }
}
#endif

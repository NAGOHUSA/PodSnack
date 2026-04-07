import Foundation
import Speech
import AVFoundation

/// On-device audio transcription powered by Apple's Speech framework.
/// All processing happens on the Neural Engine — no cloud costs.
@MainActor
final class TranscriptionService: ObservableObject {

    // MARK: - State

    enum TranscriptionState: Equatable {
        case idle
        case requestingPermission
        case transcribing(progress: Double)
        case completed
        case failed(String)
    }

    @Published var state: TranscriptionState = .idle

    // MARK: - Private

    private let recognizer: SFSpeechRecognizer?

    init(locale: Locale = .current) {
        self.recognizer = SFSpeechRecognizer(locale: locale)
    }

    // MARK: - Public API

    /// Transcribe a local audio file and return the structured `Transcript`.
    /// - Parameter audioURL: File URL of the audio to transcribe.
    func transcribe(audioURL: URL) async throws -> Transcript {
        guard let recognizer, recognizer.isAvailable else {
            throw TranscriptionError.recognizerUnavailable
        }

        let authStatus = await requestSpeechAuthorization()
        guard authStatus == .authorized else {
            throw TranscriptionError.notAuthorized
        }

        state = .transcribing(progress: 0)

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.requiresOnDeviceRecognition = true
        request.addsPunctuation = true
        request.taskHint = .dictation

        return try await withCheckedThrowingContinuation { continuation in
            var segments: [TranscriptSegment] = []

            recognizer.recognitionTask(with: request) { [weak self] result, error in
                if let error {
                    self?.state = .failed(error.localizedDescription)
                    continuation.resume(throwing: error)
                    return
                }

                guard let result else { return }

                // Accumulate timed segments from each transcription hypothesis.
                if result.isFinal {
                    for segment in result.bestTranscription.segments {
                        segments.append(
                            TranscriptSegment(
                                text: segment.substring,
                                startTime: segment.timestamp,
                                endTime: segment.timestamp + segment.duration,
                                confidence: segment.confidence
                            )
                        )
                    }

                    let transcript = Transcript(segments: segments)
                    Task { @MainActor in
                        self?.state = .completed
                    }
                    continuation.resume(returning: transcript)
                } else {
                    // Rough progress estimate based on segment count growth.
                    let progress = min(Double(result.bestTranscription.segments.count) / 100.0, 0.95)
                    Task { @MainActor in
                        self?.state = .transcribing(progress: progress)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}

// MARK: - Errors

enum TranscriptionError: LocalizedError {
    case recognizerUnavailable
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "On-device speech recognizer is not available on this device."
        case .notAuthorized:
            return "Microphone and Speech Recognition access is required. Please enable it in Settings."
        }
    }
}

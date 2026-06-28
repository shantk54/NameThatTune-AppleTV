import SwiftUI
import MusicKit

struct MusicDictationTestView: View {
    @StateObject private var musicService = AppleMusicService()

    @State private var answerText = ""
    @State private var submittedAnswer: String?
    @State private var isAnswering = false

    var body: some View {
        VStack(spacing: 32) {
            Text("Music + Dictation Test")
                .font(.largeTitle)
                .bold()

            Text("Authorization: \(String(describing: musicService.authorizationStatus))")
                .font(.title3)

            Text("Loaded songs: \(musicService.songs.count)")
                .font(.title3)

            if let firstSong = musicService.songs.first {
                Text("Test song: \(firstSong.title)")
                    .font(.title3)

                Text(firstSong.artistName)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = musicService.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.title3)
            }

            Button("Request Apple Music Access") {
                Task {
                    await musicService.requestAuthorization()
                }
            }
            .font(.title2)

            Button("Load Library Songs") {
                Task {
                    await musicService.loadLibrarySongs()
                }
            }
            .font(.title2)

            Button("Play Clip Then Dictate") {
                Task {
                    answerText = ""
                    submittedAnswer = nil
                    isAnswering = false

                    if musicService.songs.isEmpty {
                        await musicService.loadLibrarySongs()
                    }

                    await musicService.playFirstSong()

                    // Let the user hear the clip first.
                    try? await Task.sleep(nanoseconds: 8_000_000_000)

                    musicService.stop()

                    // Now open the dictation field.
                    isAnswering = true
                }
            }
            .font(.title2)

            if isAnswering && submittedAnswer == nil {
                FocusableTextField(
                    text: $answerText,
                    placeholder: "Dictate while music is playing",
                    becomeFirstResponder: true,
                    onSubmit: {
                        submitAnswer()
                    }
                )
                .frame(width: 700, height: 70)
            }

            if let submittedAnswer {
                Text("Heard: \(submittedAnswer)")
                    .font(.title2)
                    .bold()
            }

            Button("Stop Music") {
                musicService.stop()
            }
            .font(.title2)
        }
        .padding()
    }

    private func submitAnswer() {
        let cleaned = answerText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard submittedAnswer == nil, !cleaned.isEmpty else {
            return
        }

        submittedAnswer = cleaned
        isAnswering = false
    }
}

#Preview {
    MusicDictationTestView()
}

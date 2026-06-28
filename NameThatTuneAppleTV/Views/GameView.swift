import SwiftUI
import MusicKit

struct GameView: View {
    @StateObject private var musicService = AppleMusicService()

    @State private var gameSongs: [GameSong] = []
    @State private var currentRound: GameRound?
    @State private var answerText = ""
    @State private var submittedAnswer: String?
    @State private var roundNumber = 0
    @State private var score = 0
    @State private var isLoadingMusic = true
    @State private var isPlayingClip = false
    @State private var isAnswering = false
    @State private var didSetup = false

    enum FocusTarget: Hashable {
        case nextRoundButton
    }

    @FocusState private var focusedControl: FocusTarget?

    var body: some View {
        VStack(spacing: 40) {
            if isLoadingMusic {
                Text("Loading Apple Music...")
                    .font(.largeTitle)
                    .bold()

                if let errorMessage = musicService.errorMessage {
                    Text(errorMessage)
                        .font(.title3)
                        .foregroundStyle(.red)
                }
            } else if let currentRound {
                Text("Round \(currentRound.number)")
                    .font(.largeTitle)
                    .bold()

                Text("Score: \(score)")
                    .font(.title2)

                if isPlayingClip {
                    Text("Listen...")
                        .font(.title)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Say the song title and artist")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }

                if isAnswering && submittedAnswer == nil {
                    FocusableTextField(
                        text: $answerText,
                        placeholder: "Hold Siri button and speak answer",
                        becomeFirstResponder: true,
                        onSubmit: {
                            submitAnswer()
                        }
                    )
                    .frame(width: 700, height: 70)
                    .id(currentRound.number)
                } else if !answerText.isEmpty {
                    Text(answerText)
                        .font(.title2)
                        .padding()
                        .frame(width: 700, height: 70)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if let submittedAnswer {
                    Text(isCorrect(submittedAnswer, currentRound: currentRound)
                         ? "Correct!"
                         : "Wrong! It was \(currentRound.correctSong.title) by \(currentRound.correctSong.artist).")
                        .font(.title)
                        .bold()

                    Button("Next Round") {
                        startNewRound()
                    }
                    .font(.title2)
                    .focused($focusedControl, equals: .nextRoundButton)
                }
            }
        }
        .padding()
        .task {
            guard !didSetup else { return }
            didSetup = true
            await setupMusic()
            startNewRound()
        }
    }

    private func setupMusic() async {
        isLoadingMusic = true

        await musicService.requestAuthorization()
        await musicService.loadLibrarySongs()

        gameSongs = musicService.getGameSongs()

        isLoadingMusic = false
    }

    private func startNewRound() {
        let nextRoundNumber = roundNumber + 1
        let engine = GameEngine(songs: gameSongs.isEmpty ? nil : gameSongs)
        let newRound = engine.generateRound(number: nextRoundNumber)

        focusedControl = nil
        currentRound = newRound
        answerText = ""
        submittedAnswer = nil
        roundNumber = nextRoundNumber
        isPlayingClip = true
        isAnswering = false

        Task {
            await playClipThenAnswer(for: newRound.correctSong)
        }
    }

    private func playClipThenAnswer(for song: GameSong) async {
        if song.musicKitSong != nil {
            await musicService.playClip(for: song, seconds: 8)
        } else {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }

        isPlayingClip = false
        isAnswering = true
    }

    private func submitAnswer() {
        let cleaned = answerText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard submittedAnswer == nil, !cleaned.isEmpty else {
            return
        }

        submittedAnswer = cleaned
        isAnswering = false

        if let currentRound, isCorrect(cleaned, currentRound: currentRound) {
            score += 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            focusedControl = .nextRoundButton
        }
    }

    private func isCorrect(_ answer: String, currentRound: GameRound) -> Bool {
        let normalizedAnswer = normalize(answer)
        let normalizedTitle = normalize(currentRound.correctSong.title)
        let normalizedArtist = normalize(currentRound.correctSong.artist)

        // For now: accept title-only OR title + artist.
        // You can tighten this later.
        return normalizedAnswer.contains(normalizedTitle)
            || (normalizedAnswer.contains(normalizedTitle) && normalizedAnswer.contains(normalizedArtist))
    }

    private func normalize(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: " by ", with: " ")
            .replacingOccurrences(of: "&", with: "and")
            .replacingOccurrences(of: "feat.", with: "")
            .replacingOccurrences(of: "featuring", with: "")
            .filter { $0.isLetter || $0.isNumber || $0.isWhitespace }
    }
}

#Preview {
    GameView()
}

import SwiftUI

struct GameView: View {
    private let engine = GameEngine()

    @State private var currentRound: GameRound?
    @State private var answerText = ""
    @State private var submittedAnswer: String?
    @State private var roundNumber = 0
    @State private var score = 0

    enum FocusTarget: Hashable {
        case nextRoundButton
    }

    @FocusState private var focusedControl: FocusTarget?

    var body: some View {
        VStack(spacing: 40) {
            if let currentRound {
                Text("Round \(currentRound.number)")
                    .font(.largeTitle)
                    .bold()

                Text("Score: \(score)")
                    .font(.title2)

                Text("Say the song title and artist")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                if submittedAnswer == nil {
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
                } else {
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
        .onAppear {
            startNewRound()
        }
    }

    private func submitAnswer() {
        let cleaned = answerText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard submittedAnswer == nil, !cleaned.isEmpty else {
            return
        }

        submittedAnswer = cleaned

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

        return normalizedAnswer.contains(normalizedTitle)
            && normalizedAnswer.contains(normalizedArtist)
    }

    private func normalize(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: " by ", with: " ")
            .replacingOccurrences(of: "&", with: "and")
            .filter { $0.isLetter || $0.isNumber || $0.isWhitespace }
    }

    private func startNewRound() {
        let nextRoundNumber = roundNumber + 1
        let newRound = engine.generateRound(number: nextRoundNumber)

        focusedControl = nil
        currentRound = newRound
        answerText = ""
        submittedAnswer = nil
        roundNumber = nextRoundNumber
    }
}

#Preview {
    GameView()
}

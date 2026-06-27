import SwiftUI

struct GameView: View {
    private let engine = GameEngine()

    @State private var correctSong: GameSong?
    @State private var choices: [GameSong] = []
    @State private var selectedSong: GameSong?
    @State private var roundNumber = 0
    @State private var score = 0

    var body: some View {
        VStack(spacing: 40) {
            Text("Round \(roundNumber)")
                .font(.largeTitle)
                .bold()

            Text("Score: \(score)")
                .font(.title2)

            Text("Guess the song")
                .font(.title2)
                .foregroundStyle(.secondary)

            VStack(spacing: 24) {
                ForEach(choices) { song in
                    Button {
                        answer(song)
                    } label: {
                        Text(song.title)
                            .font(.title2)
                    }
                    .disabled(selectedSong != nil)
                }
            }

            if let selectedSong, let correctSong {
                Text(selectedSong == correctSong ? "Correct!" : "Wrong! It was \(correctSong.title).")
                    .font(.title)
                    .bold()

                Button("Next Round") {
                    startNewRound()
                }
                .font(.title2)
            }
        }
        .padding()
        .onAppear {
            startNewRound()
        }
    }

    private func answer(_ song: GameSong) {
        selectedSong = song

        if song == correctSong {
            score += 1
        }
    }

    private func startNewRound() {
        let round = engine.generateRound()

        correctSong = round.correct
        choices = round.choices
        selectedSong = nil
        roundNumber += 1
    }
}

#Preview {
    GameView()
}

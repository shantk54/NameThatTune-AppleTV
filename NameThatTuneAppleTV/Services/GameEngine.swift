import Foundation

class GameEngine {
    private let songs = [
        GameSong(title: "Billie Jean", artist: "Michael Jackson"),
        GameSong(title: "Africa", artist: "Toto"),
        GameSong(title: "Take On Me", artist: "a-ha"),
        GameSong(title: "September", artist: "Earth, Wind & Fire"),
        GameSong(title: "Mr. Brightside", artist: "The Killers"),
        GameSong(title: "Bohemian Rhapsody", artist: "Queen")
    ]

    func generateRound(number: Int) -> GameRound {
        let correct = songs.randomElement()!
        var choices = [correct]

        while choices.count < 4 {
            let random = songs.randomElement()!
            if !choices.contains(random) {
                choices.append(random)
            }
        }

        return GameRound(
            number: number,
            correctSong: correct,
            choices: choices.shuffled()
        )
    }
}

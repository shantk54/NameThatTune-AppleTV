import Foundation

class GameEngine {
    private var songs: [GameSong]

    init(songs: [GameSong]? = nil) {
        self.songs = songs ?? GameEngine.sampleSongs
    }

    func generateRound(number: Int) -> GameRound {
        let correct = songs.randomElement()!
        var choices = [correct]

        while choices.count < min(4, songs.count) {
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

    private static let sampleSongs = [
        GameSong(id: "sample-1", title: "Billie Jean", artist: "Michael Jackson"),
        GameSong(id: "sample-2", title: "Africa", artist: "Toto"),
        GameSong(id: "sample-3", title: "Take On Me", artist: "a-ha"),
        GameSong(id: "sample-4", title: "September", artist: "Earth, Wind & Fire"),
        GameSong(id: "sample-5", title: "Mr. Brightside", artist: "The Killers"),
        GameSong(id: "sample-6", title: "Bohemian Rhapsody", artist: "Queen")
    ]
}

internal import Foundation
import MusicKit

struct GameSong: Identifiable, Equatable {
    let id: String
    let title: String
    let artist: String
    let musicKitSong: Song?

    init(id: String = UUID().uuidString, title: String, artist: String, musicKitSong: Song? = nil) {
        self.id = id
        self.title = title
        self.artist = artist
        self.musicKitSong = musicKitSong
    }

    static func == (lhs: GameSong, rhs: GameSong) -> Bool {
        lhs.id == rhs.id
    }
}

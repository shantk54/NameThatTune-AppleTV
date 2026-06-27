import Foundation

struct GameSong: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let artist: String
}

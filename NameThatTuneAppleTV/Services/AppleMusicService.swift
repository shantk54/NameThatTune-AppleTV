import Foundation
import MusicKit
import Combine

@MainActor
final class AppleMusicService: ObservableObject {
    @Published var authorizationStatus: MusicAuthorization.Status = .notDetermined
    @Published var songs: [Song] = []
    @Published var errorMessage: String?

    private let player = ApplicationMusicPlayer.shared

    func requestAuthorization() async {
        authorizationStatus = await MusicAuthorization.request()
    }

    func loadLibrarySongs() async {
        do {
            var request = MusicLibraryRequest<Song>()
            request.limit = 25

            let response = try await request.response()
            songs = Array(response.items)
        } catch {
            errorMessage = "Failed to load songs: \(error.localizedDescription)"
        }
    }

    func playFirstSong() async {
        guard let song = songs.first else {
            errorMessage = "No songs loaded."
            return
        }

        do {
            player.queue = ApplicationMusicPlayer.Queue(for: [song], startingAt: song)
            try await player.play()
        } catch {
            errorMessage = "Failed to play song: \(error.localizedDescription)"
        }
    }

    func stop() {
        player.stop()
    }
}

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
            let nsError = error as NSError
            errorMessage = """
            Failed to play song:
            \(nsError.localizedDescription)
            Domain: \(nsError.domain)
            Code: \(nsError.code)
            Info: \(nsError.userInfo)
            """
        }
    }

    func stop() {
        player.stop()
    }
    
    func getGameSongs() -> [GameSong] {
        songs.map { song in
            GameSong(
                id: song.id.rawValue,
                title: song.title,
                artist: song.artistName,
                musicKitSong: song
            )
        }
    }

    func playClip(for gameSong: GameSong, seconds: UInt64 = 8) async {
        guard let song = gameSong.musicKitSong else {
            errorMessage = "No MusicKit song available for \(gameSong.title)."
            return
        }

        do {
            player.queue = ApplicationMusicPlayer.Queue(for: [song], startingAt: song)
            try await player.play()

            try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)

            player.stop()
        } catch {
            let nsError = error as NSError
            errorMessage = """
            Failed to play clip:
            \(nsError.localizedDescription)
            Domain: \(nsError.domain)
            Code: \(nsError.code)
            """
        }
    }
}

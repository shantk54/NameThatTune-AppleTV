import Foundation
import MusicKit
import Combine
import AVFoundation

@MainActor
final class AppleMusicService: ObservableObject {
    @Published var authorizationStatus: MusicAuthorization.Status = .notDetermined
    @Published var playlists: [Playlist] = []
    @Published var selectedPlaylist: Playlist?
    @Published var songs: [Song] = []
    @Published var errorMessage: String?

    private let player = ApplicationMusicPlayer.shared
    private var previewPlayer: AVPlayer?

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

    func loadLibraryPlaylists() async {
        do {
            var request = MusicLibraryRequest<Playlist>()
            request.limit = 100

            let response = try await request.response()
            playlists = Array(response.items)
        } catch {
            errorMessage = "Failed to load playlists: \(error.localizedDescription)"
        }
    }

    func loadSongs(from playlist: Playlist) async {
        do {
            selectedPlaylist = playlist

            let detailedPlaylist = try await playlist.with([.tracks])
            let playlistTracks = detailedPlaylist.tracks ?? []

            songs = playlistTracks.compactMap { track in
                switch track {
                case .song(let song):
                    return song
                default:
                    return nil
                }
            }

            if songs.isEmpty {
                errorMessage = "No playable songs found in \(playlist.name)."
            } else {
                errorMessage = nil
            }
        } catch {
            errorMessage = "Failed to load songs from \(playlist.name): \(error.localizedDescription)"
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
    
    func playPreviewClip(for gameSong: GameSong, seconds: UInt64 = 15) async {
        let searchTerm = "\(gameSong.title) \(gameSong.artist)"

        do {
            var searchRequest = MusicCatalogSearchRequest(
                term: searchTerm,
                types: [Song.self]
            )
            searchRequest.limit = 5

            let searchResponse = try await searchRequest.response()

            guard let catalogSong = searchResponse.songs.first else {
                errorMessage = "No catalog match found for \(gameSong.title) by \(gameSong.artist)."
                return
            }

            guard let previewURL = catalogSong.previewAssets?.first?.url else {
                errorMessage = "Catalog match found, but no preview URL for \(catalogSong.title)."
                return
            }

            errorMessage = nil

            previewPlayer?.pause()
            previewPlayer = AVPlayer(url: previewURL)
            previewPlayer?.play()

            try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)

            previewPlayer?.pause()
            previewPlayer = nil
        } catch {
            let nsError = error as NSError
            errorMessage = """
            Failed to play preview:
            \(nsError.localizedDescription)
            Domain: \(nsError.domain)
            Code: \(nsError.code)
            Info: \(nsError.userInfo)
            """
        }
    }
    
}

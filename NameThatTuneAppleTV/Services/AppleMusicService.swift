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

    private var player: ApplicationMusicPlayer {
        ApplicationMusicPlayer.shared
    }
    private var previewPlayer: AVPlayer?
    private let previewClipVolume: Float = 0.25
    private let recentPlaylistIDsKey = "recentPlaylistIDs"

    func requestAuthorization() async {
        print("AppleMusicService: requesting authorization")
        authorizationStatus = await MusicAuthorization.request()
        print("AppleMusicService: authorizationStatus = \(authorizationStatus)")
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
        print("AppleMusicService: starting playlist load")
        do {
            var request = MusicLibraryRequest<Playlist>()
            request.limit = 100

            let response = try await withTimeout(seconds: 12) {
                try await request.response()
            }
            let loadedPlaylists = Array(response.items)
            let playlistsWithArtwork = loadedPlaylists.filter { playlist in
                playlist.artwork?.url(width: 400, height: 400) != nil
            }

            print("AppleMusicService: playlists returned = \(loadedPlaylists.count)")
            print("AppleMusicService: playlists with artwork = \(playlistsWithArtwork.count)")

            if let firstPlaylist = loadedPlaylists.first {
                let firstArtworkURL = firstPlaylist.artwork?.url(width: 400, height: 400)
                print("AppleMusicService: first playlist = \(firstPlaylist.name)")
                print("AppleMusicService: first playlist artwork URL = \(String(describing: firstArtworkURL))")
            }

            playlists = sortPlaylistsByLocalRecency(loadedPlaylists)
        } catch {
            print("AppleMusicService: failed to load playlists: \(error.localizedDescription)")
            errorMessage = "Failed to load playlists: \(error.localizedDescription)"
        }
    }

    func loadSongs(from playlist: Playlist) async {
        print("AppleMusicService: loading songs from playlist = \(playlist.name)")
        do {
            selectedPlaylist = playlist
            markPlaylistAsRecentlyUsed(playlist)

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

            print("AppleMusicService: playlist tracks returned = \(playlistTracks.count)")
            print("AppleMusicService: playable songs found = \(songs.count)")

            if songs.isEmpty {
                errorMessage = "No songs found in \(playlist.name)."
            } else {
                errorMessage = nil
            }
        } catch {
            print("AppleMusicService: failed to load songs from \(playlist.name): \(error.localizedDescription)")
            errorMessage = "Failed to load songs from \(playlist.name): \(error.localizedDescription)"
        }
    }

    private func withTimeout<T>(seconds: UInt64, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: seconds * 1_000_000_000)
                throw TimeoutError()
            }

            guard let result = try await group.next() else {
                throw TimeoutError()
            }

            group.cancelAll()
            return result
        }
    }

    private struct TimeoutError: LocalizedError {
        var errorDescription: String? {
            "Apple Music request timed out."
        }
    }

    private func markPlaylistAsRecentlyUsed(_ playlist: Playlist) {
        let playlistID = playlist.id.rawValue
        var recentIDs = UserDefaults.standard.stringArray(forKey: recentPlaylistIDsKey) ?? []

        recentIDs.removeAll { $0 == playlistID }
        recentIDs.insert(playlistID, at: 0)

        UserDefaults.standard.set(Array(recentIDs.prefix(100)), forKey: recentPlaylistIDsKey)
        playlists = sortPlaylistsByLocalRecency(playlists)
    }

    private func sortPlaylistsByLocalRecency(_ playlists: [Playlist]) -> [Playlist] {
        let recentIDs = UserDefaults.standard.stringArray(forKey: recentPlaylistIDsKey) ?? []

        guard !recentIDs.isEmpty else {
            return playlists
        }

        let recentRank = Dictionary(uniqueKeysWithValues: recentIDs.enumerated().map { index, id in
            (id, index)
        })

        return playlists.sorted { lhs, rhs in
            let lhsRank = recentRank[lhs.id.rawValue] ?? Int.max
            let rhsRank = recentRank[rhs.id.rawValue] ?? Int.max

            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }

            return false
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
            previewPlayer?.volume = previewClipVolume
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

import Foundation
import MusicKit
import Combine

@MainActor
final class AlbumWallService: ObservableObject {
    @Published var authorizationStatus: MusicAuthorization.Status = .notDetermined
    @Published var albumArtworks: [Artwork] = []
    @Published var isLoading = false
    @Published var didFinishLoading = false
    @Published var errorMessage: String?

    private var libraryAlbumsWithArtwork: [Album] = []
    private var albumWallAlbums: [Album] = []
    private var isLobbyMusicPlaying = false
    private var lobbyPlayer: ApplicationMusicPlayer { ApplicationMusicPlayer.shared }

    func loadAlbumWallArtwork(targetArtworkCount: Int = 45) async {
        isLoading = true
        didFinishLoading = false
        errorMessage = nil
        print("AlbumWallService: starting album wall load")

        authorizationStatus = await MusicAuthorization.request()
        print("AlbumWallService: authorizationStatus = \(authorizationStatus)")

        guard authorizationStatus == .authorized else {
            print("AlbumWallService: not authorized, stopping album wall load")
            libraryAlbumsWithArtwork = []
            albumWallAlbums = []
            albumArtworks = []
            isLobbyMusicPlaying = false
            isLoading = false
            didFinishLoading = true
            errorMessage = "Apple Music access is required to show your album wall."
            return
        }

        do {
            var request = MusicLibraryRequest<Album>()
            request.limit = 1000

            let response = try await request.response()
            let albums = Array(response.items)
            libraryAlbumsWithArtwork = uniqueAlbumsWithArtwork(from: albums)
            let selectedAlbums = Array(libraryAlbumsWithArtwork.shuffled().prefix(targetArtworkCount))
            let randomizedArtworks = selectedAlbums.compactMap(\.artwork)

            print("AlbumWallService: albums returned = \(albums.count)")
            print("AlbumWallService: albums with artwork found = \(libraryAlbumsWithArtwork.count)")
            print("AlbumWallService: selected lobby/wall albums = \(selectedAlbums.count)")
            print("AlbumWallService: randomized artworks displayed = \(randomizedArtworks.count)")
            if let firstArtworkURL = randomizedArtworks.first?.url(width: 400, height: 400) {
                print("AlbumWallService: first displayed artwork URL = \(firstArtworkURL)")
            } else if let firstAlbum = albums.first {
                print("AlbumWallService: first album has artwork = \(firstAlbum.artwork != nil), title = \(firstAlbum.title), artist = \(firstAlbum.artistName)")
            }

            albumWallAlbums = selectedAlbums
            albumArtworks = randomizedArtworks
            print("AlbumWallService: about to start lobby music from album wall selection")
            await playRandomLobbyMusic()
            isLoading = false
            didFinishLoading = true
        } catch {
            print("AlbumWallService: failed to load album artwork: \(error.localizedDescription)")
            libraryAlbumsWithArtwork = []
            albumWallAlbums = []
            albumArtworks = []
            isLobbyMusicPlaying = false
            isLoading = false
            didFinishLoading = true
            errorMessage = "Failed to load album artwork: \(error.localizedDescription)"
        }
    }

    func refreshAlbumWallArtwork(targetArtworkCount: Int = 45) {
        guard !libraryAlbumsWithArtwork.isEmpty else {
            print("AlbumWallService: cannot refresh album wall because no cached albums are available")
            return
        }

        let selectedAlbums = Array(libraryAlbumsWithArtwork.shuffled().prefix(targetArtworkCount))
        let randomizedArtworks = selectedAlbums.compactMap(\.artwork)

        albumWallAlbums = selectedAlbums
        albumArtworks = randomizedArtworks

        print("AlbumWallService: refreshed album wall albums = \(selectedAlbums.count)")
        print("AlbumWallService: refreshed album wall artworks = \(randomizedArtworks.count)")
    }

    func playRandomLobbyMusic() async {
        guard !isLobbyMusicPlaying else {
            print("AlbumWallService: lobby music already playing")
            return
        }

        let albumsToSearch = albumWallAlbums.shuffled()
        print("AlbumWallService: starting lobby music search, albums available = \(albumsToSearch.count)")

        guard !albumsToSearch.isEmpty else {
            print("AlbumWallService: no album wall albums available for lobby music")
            return
        }

        for album in albumsToSearch {
            do {
                print("AlbumWallService: trying lobby album = \(album.title)")
                let detailedAlbum = try await withTimeout(seconds: 6) {
                    try await album.with([.tracks])
                }

                let songs = detailedAlbum.tracks?.compactMap { track -> Song? in
                    if case .song(let song) = track {
                        return song
                    }

                    return nil
                } ?? []

                print("AlbumWallService: lobby album tracks found = \(songs.count) for \(album.title)")

                guard let song = songs.randomElement() else {
                    print("AlbumWallService: no songs found for lobby album = \(album.title)")
                    continue
                }

                print("AlbumWallService: selected lobby song = \(song.title), album = \(album.title)")
                lobbyPlayer.stop()
                lobbyPlayer.queue = [song]
                try await withTimeout(seconds: 6) {
                    try await self.lobbyPlayer.play()
                }
                isLobbyMusicPlaying = true
                print("AlbumWallService: playing lobby music full song = \(song.title), album = \(album.title)")
                return
            } catch {
                print("AlbumWallService: failed lobby music attempt for album \(album.title): \(error.localizedDescription)")
            }
        }

        isLobbyMusicPlaying = false
        print("AlbumWallService: could not find a playable lobby song from selected album wall albums")
    }

    func stopLobbyMusic() {
        lobbyPlayer.stop()
        isLobbyMusicPlaying = false
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

    private func uniqueAlbumsWithArtwork(from albums: [Album]) -> [Album] {
        var seenArtworkURLs: Set<String> = []

        return albums.compactMap { album in
            guard let artwork = album.artwork,
                  let artworkURL = artwork.url(width: 400, height: 400) else {
                return nil
            }

            let artworkKey = artworkURL.absoluteString
            guard !seenArtworkURLs.contains(artworkKey) else {
                return nil
            }

            seenArtworkURLs.insert(artworkKey)
            return album
        }
    }
}

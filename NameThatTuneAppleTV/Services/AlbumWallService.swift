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

    func loadAlbumWallArtwork() async {
        isLoading = true
        didFinishLoading = false
        errorMessage = nil
        print("AlbumWallService: starting album wall load")

        authorizationStatus = await MusicAuthorization.request()
        print("AlbumWallService: authorizationStatus = \(authorizationStatus)")

        guard authorizationStatus == .authorized else {
            print("AlbumWallService: not authorized, stopping album wall load")
            albumArtworks = []
            isLoading = false
            didFinishLoading = true
            errorMessage = "Apple Music access is required to show your album wall."
            return
        }

        do {
            var request = MusicLibraryRequest<Song>()
            request.limit = 100

            let response = try await request.response()
            let songs = Array(response.items)
            let artworks = uniqueArtworks(from: songs)

            print("AlbumWallService: songs returned = \(songs.count)")
            print("AlbumWallService: artworks found = \(artworks.count)")
            if let firstArtworkURL = artworks.first?.url(width: 400, height: 400) {
                print("AlbumWallService: first artwork URL = \(firstArtworkURL)")
            } else if let firstSong = songs.first {
                print("AlbumWallService: first song has artwork = \(firstSong.artwork != nil), title = \(firstSong.title), artist = \(firstSong.artistName)")
            }

            albumArtworks = artworks
            isLoading = false
            didFinishLoading = true
        } catch {
            print("AlbumWallService: failed to load album artwork: \(error.localizedDescription)")
            albumArtworks = []
            isLoading = false
            didFinishLoading = true
            errorMessage = "Failed to load album artwork: \(error.localizedDescription)"
        }
    }

    private func uniqueArtworks(from songs: [Song]) -> [Artwork] {
        var seenArtworkURLs: Set<String> = []

        return songs.compactMap { song in
            guard let artwork = song.artwork,
                  let artworkURL = artwork.url(width: 400, height: 400) else {
                return nil
            }

            let artworkKey = artworkURL.absoluteString
            guard !seenArtworkURLs.contains(artworkKey) else {
                return nil
            }

            seenArtworkURLs.insert(artworkKey)
            return artwork
        }
    }
}

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

    func loadAlbumWallArtwork(targetArtworkCount: Int = 45) async {
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
            var request = MusicLibraryRequest<Album>()
            request.limit = 700

            let response = try await request.response()
            let albums = Array(response.items)
            let artworks = uniqueArtworks(from: albums)
            let randomizedArtworks = Array(artworks.shuffled().prefix(targetArtworkCount))

            print("AlbumWallService: albums returned = \(albums.count)")
            print("AlbumWallService: album artworks found = \(artworks.count)")
            print("AlbumWallService: randomized artworks displayed = \(randomizedArtworks.count)")
            if let firstArtworkURL = randomizedArtworks.first?.url(width: 400, height: 400) {
                print("AlbumWallService: first displayed artwork URL = \(firstArtworkURL)")
            } else if let firstAlbum = albums.first {
                print("AlbumWallService: first album has artwork = \(firstAlbum.artwork != nil), title = \(firstAlbum.title), artist = \(firstAlbum.artistName)")
            }

            albumArtworks = randomizedArtworks
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

    private func uniqueArtworks(from albums: [Album]) -> [Artwork] {
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
            return artwork
        }
    }
}

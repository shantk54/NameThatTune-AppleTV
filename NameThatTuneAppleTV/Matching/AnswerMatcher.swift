import Foundation

struct AnswerMatchResult {
    let songPoints: Int
    let artistPoints: Int
    let matchedSongTitle: String?
    let matchedArtist: String?

    var total: Int {
        songPoints + artistPoints
    }
}

struct AnswerMatcher {
    let playlistSongs: [GameSong]

    func score(answer: String, correctSong: GameSong) -> AnswerMatchResult {
        let bestSong = bestMatchingSongTitle(for: answer)
        let bestArtist = bestMatchingArtist(for: answer)

        let songPoints = bestSong?.song.id == correctSong.id && bestSong?.confidence ?? 0 >= 0.72 ? 10 : 0
        let artistPoints = normalize(removeFeaturing(from: bestArtist?.artist ?? "")) == normalize(removeFeaturing(from: correctSong.artist))
            && bestArtist?.confidence ?? 0 >= 0.72 ? 10 : 0

        return AnswerMatchResult(
            songPoints: songPoints,
            artistPoints: artistPoints,
            matchedSongTitle: bestSong?.song.title,
            matchedArtist: bestArtist?.artist
        )
    }

    private func bestMatchingSongTitle(for answer: String) -> (song: GameSong, confidence: Double)? {
        playlistSongs
            .map { song in
                (song: song, confidence: similarity(answer, removeFeaturing(from: removeParentheses(from: song.title))))
            }
            .max { lhs, rhs in
                lhs.confidence < rhs.confidence
            }
    }

    private func bestMatchingArtist(for answer: String) -> (artist: String, confidence: Double)? {
        let artists = Array(Set(playlistSongs.map { removeFeaturing(from: $0.artist) }))

        return artists
            .map { artist in
                (artist: artist, confidence: similarity(answer, artist))
            }
            .max { lhs, rhs in
                lhs.confidence < rhs.confidence
            }
    }

    private func similarity(_ guess: String, _ target: String) -> Double {
        let normalizedGuess = normalize(guess)
        let normalizedTarget = normalize(target)

        guard !normalizedGuess.isEmpty, !normalizedTarget.isEmpty else {
            return 0
        }

        let compactGuess = compactNormalize(guess)
        let compactTarget = compactNormalize(target)

        if normalizedGuess.contains(normalizedTarget) || compactGuess.contains(compactTarget) {
            return 1.0
        }

        let distance = levenshteinDistance(compactGuess, compactTarget)
        let maxLength = max(compactGuess.count, compactTarget.count)

        guard maxLength > 0 else {
            return 0
        }

        return 1.0 - (Double(distance) / Double(maxLength))
    }

    private func removeParentheses(from text: String) -> String {
        text.replacingOccurrences(
            of: #"\s*\([^)]*\)"#,
            with: "",
            options: .regularExpression
        )
    }

    private func removeFeaturing(from text: String) -> String {
        text.replacingOccurrences(
            of: #"\s*(?:\(|\[)?\s*(?:feat\.?|featuring|ft\.?)\b.*$"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalize(_ text: String) -> String {
        let cleaned = removeFeaturing(from: text)
            .lowercased()
            .replacingOccurrences(of: "&", with: " and ")
            .replacingOccurrences(of: "feat.", with: " ")
            .replacingOccurrences(of: "featuring", with: " ")
            .replacingOccurrences(
                of: #"[^a-z0-9]+"#,
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )
    }

    private func compactNormalize(_ text: String) -> String {
        normalize(text).replacingOccurrences(of: " ", with: "")
    }

    private func levenshteinDistance(_ lhs: String, _ rhs: String) -> Int {
        let lhsArray = Array(lhs)
        let rhsArray = Array(rhs)

        if lhsArray.isEmpty { return rhsArray.count }
        if rhsArray.isEmpty { return lhsArray.count }

        var previousRow = Array(0...rhsArray.count)
        var currentRow = Array(repeating: 0, count: rhsArray.count + 1)

        for lhsIndex in 1...lhsArray.count {
            currentRow[0] = lhsIndex

            for rhsIndex in 1...rhsArray.count {
                let deleteCost = previousRow[rhsIndex] + 1
                let insertCost = currentRow[rhsIndex - 1] + 1
                let replaceCost = previousRow[rhsIndex - 1] + (lhsArray[lhsIndex - 1] == rhsArray[rhsIndex - 1] ? 0 : 1)

                currentRow[rhsIndex] = min(deleteCost, insertCost, replaceCost)
            }

            previousRow = currentRow
        }

        return previousRow[rhsArray.count]
    }
}

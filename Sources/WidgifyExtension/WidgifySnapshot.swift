import Foundation

struct WidgifySnapshot: Equatable {
    var title: String
    var artist: String
    var album: String
    var artworkURL: URL?
    var artworkData: Data?
    var position: TimeInterval
    var duration: TimeInterval
    var isPlaying: Bool
    var isShuffling: Bool
    var status: String

    static let idle = WidgifySnapshot(
        title: "Spotify",
        artist: "Start playback",
        album: "",
        artworkURL: nil,
        artworkData: nil,
        position: 0,
        duration: 0,
        isPlaying: false,
        isShuffling: false,
        status: "Not playing"
    )
}

struct WidgifyLyrics: Equatable {
    struct Line: Equatable {
        var time: TimeInterval?
        var text: String
    }

    var status: String
    var lines: [Line]
    var isSynced: Bool

    static let idle = WidgifyLyrics(status: "Lyrics", lines: [], isSynced: false)

    var hasLyrics: Bool {
        !lines.isEmpty
    }

    func visibleLines(at position: TimeInterval, limit: Int = 3) -> [Line] {
        guard hasLyrics else { return [] }
        guard isSynced else {
            return Array(lines.prefix(limit))
        }

        let currentIndex = lines.lastIndex { line in
            guard let time = line.time else { return false }
            return time <= position + 0.35
        } ?? 0

        let start = max(0, currentIndex - 1)
        let end = min(lines.count, start + limit)
        return Array(lines[start..<end])
    }

    func isCurrent(_ line: Line, at position: TimeInterval) -> Bool {
        guard isSynced, let index = lines.firstIndex(of: line), let time = line.time else {
            return false
        }
        let nextTime = lines.dropFirst(index + 1).first { $0.time != nil }?.time ?? .infinity
        return time <= position + 0.35 && position < nextTime
    }
}

enum LyricsPageStore {
    private static let cache = LyricsPageCache()

    static func key(for snapshot: WidgifySnapshot) -> String {
        [
            snapshot.title.lowercased(),
            snapshot.artist.lowercased(),
            snapshot.album.lowercased(),
            String(Int(snapshot.duration.rounded()))
        ].joined(separator: "|")
    }

    static func page(for trackKey: String, maxPage: Int) -> Int {
        min(max(cache.page(for: trackKey), 0), maxPage)
    }

    static func move(trackKey: String, direction: LyricsPageDirection, maxPage: Int) {
        let currentPage = page(for: trackKey, maxPage: maxPage)
        let nextPage: Int
        switch direction {
        case .previous:
            nextPage = max(0, currentPage - 1)
        case .next:
            nextPage = min(maxPage, currentPage + 1)
        }
        cache.store(nextPage, for: trackKey)
    }
}

enum WidgifyReader {
    static func currentSnapshot(loadArtwork: Bool = true) -> WidgifySnapshot {
        if let bridgedSnapshot = currentSnapshotFromHostApp(loadArtwork: loadArtwork) {
            return bridgedSnapshot
        }

        let output = runAppleScript(trackScript)
        let parts = output.components(separatedBy: "\n")

        guard parts.first != "NOT_RUNNING" else {
            var snapshot = WidgifySnapshot.idle
            snapshot.artist = "Open Spotify"
            snapshot.status = "Spotify is closed"
            return snapshot
        }

        guard parts.first != "NO_TRACK", parts.count >= 8 else {
            return WidgifySnapshot.idle
        }

        let artworkURL = URL(string: parts[3])
        var artworkData: Data?
        if loadArtwork, let artworkURL {
            artworkData = remoteData(from: artworkURL, timeout: 1.2)
        }

        return WidgifySnapshot(
            title: parts[0].isEmpty ? "Unknown track" : parts[0],
            artist: parts[1].isEmpty ? "Unknown artist" : parts[1],
            album: parts[2],
            artworkURL: artworkURL,
            artworkData: artworkData,
            position: TimeInterval(parts[5]) ?? 0,
            duration: (TimeInterval(parts[6]) ?? 0) / 1000,
            isPlaying: parts[4] == "playing",
            isShuffling: parts[7] == "true",
            status: parts[4] == "playing" ? "Playing" : "Paused"
        )
    }

    private struct HostedSnapshot: Decodable {
        var title: String
        var artist: String
        var album: String
        var artworkURL: String
        var position: TimeInterval
        var duration: TimeInterval
        var isPlaying: Bool
        var isShuffling: Bool?
        var status: String
    }

    private static func currentSnapshotFromHostApp(loadArtwork: Bool) -> WidgifySnapshot? {
        guard let url = URL(string: "http://127.0.0.1:47391/snapshot") else { return nil }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 0.8

        guard let data = try? EphemeralNetworkSession.shared.synchronousData(for: request),
              let hosted = try? JSONDecoder().decode(HostedSnapshot.self, from: data) else {
            return nil
        }

        let artworkURL = URL(string: hosted.artworkURL)
        var artworkData: Data?
        if loadArtwork, let artworkURL {
            artworkData = remoteData(from: artworkURL, timeout: 1.2)
        }

        return WidgifySnapshot(
            title: hosted.title,
            artist: hosted.artist,
            album: hosted.album,
            artworkURL: artworkURL,
            artworkData: artworkData,
            position: hosted.position,
            duration: hosted.duration,
            isPlaying: hosted.isPlaying,
            isShuffling: hosted.isShuffling ?? false,
            status: hosted.status
        )
    }

    static func send(_ command: WidgifyCommand) {
        if sendToHostApp(command) {
            return
        }

        let verb: String
        switch command {
        case .previous:
            verb = "previous track"
        case .play:
            verb = "play"
        case .pause:
            verb = "pause"
        case .playPause:
            verb = "playpause"
        case .next:
            verb = "next track"
        case .shuffle:
            _ = runAppleScript("""
            if application id "com.spotify.client" is running then
                tell application id "com.spotify.client" to set shuffling to not shuffling
            else
                tell application id "com.spotify.client" to activate
            end if
            """)
            return
        case .openSpotify:
            _ = runAppleScript("""
            tell application id "com.spotify.client" to activate
            """)
            return
        }

        _ = runAppleScript("""
        if application id "com.spotify.client" is running then
            tell application id "com.spotify.client" to \(verb)
        else
            tell application id "com.spotify.client" to activate
        end if
        """)
    }

    private static func sendToHostApp(_ command: WidgifyCommand) -> Bool {
        guard var components = URLComponents(string: "http://127.0.0.1:47391/command") else {
            return false
        }
        components.queryItems = [URLQueryItem(name: "command", value: command.rawValue)]
        guard let url = components.url else { return false }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 0.6

        for attempt in 0..<5 {
            if attempt > 0 {
                Thread.sleep(forTimeInterval: 0.2)
            }

            guard let (_, response) = try? EphemeralNetworkSession.shared.synchronousResponse(for: request),
                  let httpResponse = response as? HTTPURLResponse else {
                continue
            }

            if (200..<300).contains(httpResponse.statusCode) {
                return true
            }
        }

        return false
    }

    private static func runAppleScript(_ source: String) -> String {
        guard let script = NSAppleScript(source: source) else {
            return "NO_TRACK"
        }

        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        guard error == nil else { return "NO_TRACK" }
        return result.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func remoteData(from url: URL, timeout: TimeInterval) -> Data? {
        if let cachedData = RemoteDataCache.shared.value(for: url) {
            return cachedData
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = timeout

        guard let data = try? EphemeralNetworkSession.shared.synchronousData(for: request), !data.isEmpty else {
            return nil
        }

        RemoteDataCache.shared.store(data, for: url)
        return data
    }

    private static let trackScript = """
    if application "Spotify" is running then
        tell application "Spotify"
            try
                set theTrack to current track
                set trackName to name of theTrack
                set artistName to artist of theTrack
                set albumName to album of theTrack
                set artURL to artwork url of theTrack
                set playState to player state as string
                set playPosition to player position as string
                set trackDuration to duration of theTrack as string
                set shuffleState to shuffling as string
                return trackName & linefeed & artistName & linefeed & albumName & linefeed & artURL & linefeed & playState & linefeed & playPosition & linefeed & trackDuration & linefeed & shuffleState
            on error
                return "NO_TRACK"
            end try
        end tell
    else
        return "NOT_RUNNING"
    end if
    """

}

enum LyricsReader {
    private struct LRCLIBRecord: Decodable {
        var instrumental: Bool
        var plainLyrics: String?
        var syncedLyrics: String?
    }

    private static let cache = LyricsCache()

    static func lyrics(for snapshot: WidgifySnapshot) -> WidgifyLyrics {
        guard snapshot.title != WidgifySnapshot.idle.title,
              snapshot.artist != WidgifySnapshot.idle.artist,
              snapshot.duration > 0 else {
            return .idle
        }

        let key = cacheKey(for: snapshot)
        if let cached = cachedLyrics(for: key) {
            return cached
        }

        let lyrics = fetchLyrics(for: snapshot)
        store(lyrics, for: key)
        return lyrics
    }

    private static func fetchLyrics(for snapshot: WidgifySnapshot) -> WidgifyLyrics {
        guard var components = URLComponents(string: "https://lrclib.net/api/get") else {
            return WidgifyLyrics(status: "Lyrics unavailable", lines: [], isSynced: false)
        }

        components.queryItems = [
            URLQueryItem(name: "track_name", value: snapshot.title),
            URLQueryItem(name: "artist_name", value: snapshot.artist),
            URLQueryItem(name: "album_name", value: snapshot.album),
            URLQueryItem(name: "duration", value: String(Int(snapshot.duration.rounded())))
        ]

        guard let url = components.url else {
            return WidgifyLyrics(status: "Lyrics unavailable", lines: [], isSynced: false)
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 1.5
        request.setValue("Widgify/1.0 (https://lrclib.net)", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? EphemeralNetworkSession.shared.synchronousResponse(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let record = try? JSONDecoder().decode(LRCLIBRecord.self, from: data) else {
            return WidgifyLyrics(status: "No lyrics found", lines: [], isSynced: false)
        }

        if record.instrumental {
            return WidgifyLyrics(status: "Instrumental", lines: [], isSynced: false)
        }

        if let syncedLyrics = record.syncedLyrics,
           let lyrics = parseSyncedLyrics(syncedLyrics),
           lyrics.hasLyrics {
            return lyrics
        }

        if let plainLyrics = record.plainLyrics {
            let lines = plainLyrics
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { WidgifyLyrics.Line(time: nil, text: $0) }

            if !lines.isEmpty {
                return WidgifyLyrics(status: "Lyrics", lines: lines, isSynced: false)
            }
        }

        return WidgifyLyrics(status: "No lyrics found", lines: [], isSynced: false)
    }

    private static func parseSyncedLyrics(_ source: String) -> WidgifyLyrics? {
        let lines = source
            .components(separatedBy: .newlines)
            .compactMap(parseSyncedLine)
            .filter { !$0.text.isEmpty }

        guard !lines.isEmpty else { return nil }
        return WidgifyLyrics(status: "Synced lyrics", lines: lines, isSynced: true)
    }

    private static func parseSyncedLine(_ source: String) -> WidgifyLyrics.Line? {
        guard let close = source.firstIndex(of: "]") else { return nil }
        let timeToken = source[source.index(after: source.startIndex)..<close]
        let text = source[source.index(after: close)...]
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let time = parseTime(String(timeToken)) else { return nil }
        return WidgifyLyrics.Line(time: time, text: text)
    }

    private static func parseTime(_ source: String) -> TimeInterval? {
        let parts = source.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2,
              let minutes = TimeInterval(parts[0]),
              let seconds = TimeInterval(parts[1]) else {
            return nil
        }
        return minutes * 60 + seconds
    }

    private static func cacheKey(for snapshot: WidgifySnapshot) -> String {
        [
            snapshot.title.lowercased(),
            snapshot.artist.lowercased(),
            snapshot.album.lowercased(),
            String(Int(snapshot.duration.rounded()))
        ].joined(separator: "|")
    }

    private static func cachedLyrics(for key: String) -> WidgifyLyrics? {
        cache.value(for: key)
    }

    private static func store(_ lyrics: WidgifyLyrics, for key: String) {
        cache.store(lyrics, for: key)
    }
}

private final class LyricsPageCache: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Int] = [:]

    func page(for key: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return values[key] ?? 0
    }

    func store(_ page: Int, for key: String) {
        lock.lock()
        values[key] = page
        lock.unlock()
    }
}

private final class LyricsCache: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: WidgifyLyrics] = [:]

    func value(for key: String) -> WidgifyLyrics? {
        lock.lock()
        defer { lock.unlock() }
        return values[key]
    }

    func store(_ lyrics: WidgifyLyrics, for key: String) {
        lock.lock()
        values[key] = lyrics
        lock.unlock()
    }
}

private enum EphemeralNetworkSession {
    static let shared: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        return URLSession(configuration: configuration)
    }()
}

private final class RemoteDataCache: @unchecked Sendable {
    static let shared = RemoteDataCache()

    private let lock = NSLock()
    private var values: [URL: Data] = [:]
    private var keys: [URL] = []
    private let limit = 8

    func value(for url: URL) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return values[url]
    }

    func store(_ data: Data, for url: URL) {
        lock.lock()
        defer { lock.unlock() }

        if values[url] == nil {
            keys.append(url)
        }
        values[url] = data

        while keys.count > limit {
            let removed = keys.removeFirst()
            values.removeValue(forKey: removed)
        }
    }
}

private final class URLSessionResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Result<(Data, URLResponse?), Error>?

    func store(_ result: Result<(Data, URLResponse?), Error>) {
        lock.lock()
        value = result
        lock.unlock()
    }

    func result() -> Result<(Data, URLResponse?), Error>? {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

private extension URLSession {
    func synchronousData(for request: URLRequest) throws -> Data {
        let (data, _) = try synchronousResponse(for: request)
        return data
    }

    func synchronousResponse(for request: URLRequest) throws -> (Data, URLResponse?) {
        let semaphore = DispatchSemaphore(value: 0)
        let resultBox = URLSessionResultBox()

        dataTask(with: request) { data, response, error in
            if let error {
                resultBox.store(.failure(error))
            } else {
                resultBox.store(.success((data ?? Data(), response)))
            }
            semaphore.signal()
        }.resume()

        _ = semaphore.wait(timeout: .now() + request.timeoutInterval)
        return try resultBox.result()?.get() ?? (Data(), nil)
    }
}

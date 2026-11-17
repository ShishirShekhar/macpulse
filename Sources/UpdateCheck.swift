import Foundation

/// Opt-in, isolated update check against public GitHub Releases.
///
/// Invariants:
/// - Strictly opt-in: no network request is ever performed unless explicitly
///   enabled by the user or triggered by clicking "Check for Updates…".
/// - Zero telemetry, zero analytics, zero machine identifiers.
/// - Read-only GET request to GitHub's public API.
enum UpdateCheck {
    static let enabledKey = "checkForUpdatesEnabled"
    static let lastCheckedKey = "lastUpdateCheckDate"
    static let endpoint = URL(string: "https://api.github.com/repos/ShishirShekhar/macpulse/releases/latest")!

    struct ReleaseInfo: Equatable {
        let tagName: String
        let htmlURL: String
        let isPrerelease: Bool
    }

    /// Pure comparison of semantic versions (e.g. "1.2.1" > "1.2.0", "v1.3.0" > "1.2.0").
    static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let cleanCandidate = candidate.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
        let cleanCurrent = current.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))

        let candidateParts = cleanCandidate.split(separator: ".").compactMap { Int($0) }
        let currentParts = cleanCurrent.split(separator: ".").compactMap { Int($0) }

        guard !candidateParts.isEmpty, !currentParts.isEmpty else { return false }

        let count = max(candidateParts.count, currentParts.count)
        for i in 0..<count {
            let c = i < candidateParts.count ? candidateParts[i] : 0
            let curr = i < currentParts.count ? currentParts[i] : 0
            if c > curr { return true }
            if c < curr { return false }
        }
        return false
    }

    /// Parses the GitHub release JSON safely.
    static func parseRelease(data: Data) -> ReleaseInfo? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tagName = obj["tag_name"] as? String,
              let htmlURL = obj["html_url"] as? String else {
            return nil
        }
        let prerelease = obj["prerelease"] as? Bool ?? false
        return ReleaseInfo(tagName: tagName, htmlURL: htmlURL, isPrerelease: prerelease)
    }

    /// Performs an asynchronous update check if invoked. Callers MUST ensure
    /// that user consent (opt-in) is respected.
    static func check(
        currentVersion: String = "1.7.0",
        session: URLSession = .shared,
        completion: @escaping (Result<ReleaseInfo?, Error>) -> Void
    ) {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.setValue("MacPulse/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let data = data,
                  let release = parseRelease(data: data) else {
                completion(.success(nil))
                return
            }

            if isVersion(release.tagName, newerThan: currentVersion) {
                completion(.success(release))
            } else {
                completion(.success(nil))
            }
        }
        task.resume()
    }
}

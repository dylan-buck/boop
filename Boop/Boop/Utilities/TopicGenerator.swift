import Foundation

struct TopicGenerator {
    private static let characters = "abcdefghijklmnopqrstuvwxyz0123456789"
    private static let topicLength = 24
    private static let prefix = "boop-"

    static func generate() -> String {
        var randomString = ""
        for _ in 0..<topicLength {
            let randomIndex = Int.random(in: 0..<characters.count)
            let index = characters.index(characters.startIndex, offsetBy: randomIndex)
            randomString.append(characters[index])
        }
        return prefix + randomString
    }

    static func isValid(_ topic: String) -> Bool {
        guard topic.hasPrefix(prefix) else { return false }
        let suffix = String(topic.dropFirst(prefix.count))
        guard suffix.count == topicLength else { return false }
        return suffix.allSatisfy { characters.contains($0) }
    }
}

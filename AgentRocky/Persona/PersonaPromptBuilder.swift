import Foundation

/// Loads the Rocky persona prompt from the bundled resource.
nonisolated enum PersonaPromptBuilder {

    enum LoadError: Error, Equatable {
        case resourceMissing
        case readFailed(detail: String)
    }

    /// Loads `rocky-persona.txt` from the main bundle.
    static func load() throws(LoadError) -> String {
        guard let url = Bundle.main.url(forResource: "rocky-persona", withExtension: "txt") else {
            throw .resourceMissing
        }
        do {
            return try String(contentsOf: url, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            throw .readFailed(detail: error.localizedDescription)
        }
    }
}

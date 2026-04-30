import Testing
@testable import AgentRocky

struct CommandDispatcherTests {
    let dispatcher = CommandDispatcher()

    @Test("/clear is recognized")
    func clear_command() {
        #expect(dispatcher.interpret("/clear") == .command(.clear))
    }

    @Test("/copy is recognized")
    func copy_command() {
        #expect(dispatcher.interpret("/copy") == .command(.copy))
    }

    @Test("/help is recognized")
    func help_command() {
        #expect(dispatcher.interpret("/help") == .command(.help))
    }

    @Test("Unknown slash commands surface as .unknownCommand with the original text")
    func unknown_slash_command() {
        #expect(dispatcher.interpret("/foo") == .unknownCommand("/foo"))
    }

    @Test("Plain messages pass through")
    func plain_message_passes_through() {
        #expect(dispatcher.interpret("hello rocky") == .message("hello rocky"))
    }

    @Test("Leading/trailing whitespace stripped before interpretation")
    func leading_whitespace_trimmed() {
        #expect(dispatcher.interpret("   /clear   ") == .command(.clear))
    }

    @Test("A path-like message containing slashes still passes through as a message")
    func message_with_slash_inside_passes_through() {
        #expect(
            dispatcher.interpret("show me path/to/file") == .message("show me path/to/file")
        )
    }

    @Test("Empty / whitespace-only input → empty message")
    func empty_passes_through_as_empty_message() {
        #expect(dispatcher.interpret("") == .message(""))
        #expect(dispatcher.interpret("   ") == .message(""))
    }
}

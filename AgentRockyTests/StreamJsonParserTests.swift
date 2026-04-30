import Testing
@testable import AgentRocky

struct StreamJsonParserTests {

    @Test("system/init yields sessionReady")
    func system_init_yields_session_ready() {
        let parser = StreamJsonParser()
        let line = #"{"type":"system","subtype":"init"}"# + "\n"
        let events = parser.feed(line)
        #expect(events.count == 1)
        if case .sessionReady = events[0] {} else { Issue.record("expected .sessionReady") }
    }

    @Test("assistant text block yields textDelta")
    func assistant_text_yields_text_delta() {
        let parser = StreamJsonParser()
        let line = #"{"type":"assistant","message":{"content":[{"type":"text","text":"hello"}]}}"# + "\n"
        let events = parser.feed(line)
        #expect(events.count == 1)
        if case .textDelta(let s) = events[0] {
            #expect(s == "hello")
        } else { Issue.record("expected .textDelta") }
    }

    @Test("result yields turnComplete")
    func result_yields_turn_complete() {
        let parser = StreamJsonParser()
        let line = #"{"type":"result","subtype":"success"}"# + "\n"
        let events = parser.feed(line)
        #expect(events.count == 1)
        if case .turnComplete = events[0] {} else { Issue.record("expected .turnComplete") }
    }

    @Test("partial line buffers until newline")
    func partial_line_buffers_until_newline() {
        let parser = StreamJsonParser()
        let part1 = #"{"type":"assistant","message":{"content"#
        let part2 = #":[{"type":"text","text":"foo"}]}}"# + "\n"
        #expect(parser.feed(part1).isEmpty)
        let events = parser.feed(part2)
        #expect(events.count == 1)
    }

    @Test("multiple events in one buffer")
    func multiple_events_in_one_buffer() {
        let parser = StreamJsonParser()
        let buffer = #"{"type":"system","subtype":"init"}"# + "\n" +
                     #"{"type":"assistant","message":{"content":[{"type":"text","text":"a"}]}}"# + "\n"
        let events = parser.feed(buffer)
        #expect(events.count == 2)
    }

    @Test("malformed JSON emits streamCorrupt error")
    func malformed_json_emits_stream_corrupt_error() {
        let parser = StreamJsonParser()
        let events = parser.feed("{not valid json}\n")
        #expect(events.count == 1)
        if case .error(let err) = events[0], case .streamCorrupt = err {} else {
            Issue.record("expected .error(.streamCorrupt)")
        }
    }

    @Test("hook_started, hook_response, post_turn_summary are silently ignored")
    func hooks_ignored() {
        let parser = StreamJsonParser()
        let events = parser.feed(
            #"{"type":"system","subtype":"hook_started","hook_id":"x"}"# + "\n" +
            #"{"type":"system","subtype":"post_turn_summary"}"# + "\n"
        )
        #expect(events.isEmpty)
    }

    @Test("tool_use yields toolCall")
    func tool_use_yields_tool_call() {
        let parser = StreamJsonParser()
        let line = #"{"type":"assistant","message":{"content":[{"type":"tool_use","id":"1","name":"Read","input":{"file_path":"/tmp/foo"}}]}}"# + "\n"
        let events = parser.feed(line)
        #expect(events.count == 1)
        if case .toolCall(let name, _) = events[0] {
            #expect(name == "Read")
        } else { Issue.record("expected .toolCall") }
    }

    @Test("tool_result yields toolResult with success flipped from is_error")
    func tool_result_yields_tool_result() {
        let parser = StreamJsonParser()
        let line = #"{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"1","is_error":false,"content":"ok"}]}}"# + "\n"
        let events = parser.feed(line)
        #expect(events.count == 1)
        if case .toolResult(_, let success) = events[0] {
            #expect(success)
        } else { Issue.record("expected .toolResult") }
    }
}

import SwiftUI

struct TerminalView: View {
    @Environment(\.theme) private var theme
    @Bindable var viewModel: ChatViewModel
    var onCopyLast: () -> Void = {}
    var onClose: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(theme.foreground.opacity(0.1))
            transcript
            Divider().background(theme.foreground.opacity(0.1))
            input
        }
        .background(theme.background)
        .foregroundStyle(theme.foreground)
        .frame(minWidth: 320, idealWidth: 360, minHeight: 360, idealHeight: 480)
    }

    private var header: some View {
        HStack {
            Text("Rocky").font(.headline)
            Spacer()
            Button { onCopyLast() } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.plain)
            .help("Copy last response")

            Button { onClose() } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if viewModel.transcript.isEmpty {
                    emptyState
                } else {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.transcript) { msg in
                            messageRow(msg).id(msg.id)
                        }
                        Spacer().frame(height: 4).id("bottomAnchor")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
            .onChange(of: viewModel.transcript.last?.text) { _, _ in
                withAnimation(.linear(duration: 0.05)) {
                    proxy.scrollTo("bottomAnchor", anchor: .bottom)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer().frame(height: 80)
            Text("Hi, Questioner")
                .font(.headline)
                .foregroundStyle(theme.foreground.opacity(0.7))
            Text("Ask Rocky something. /help for commands.")
                .font(theme.monoFont)
                .foregroundStyle(theme.foreground.opacity(0.5))
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    @ViewBuilder
    private func messageRow(_ msg: AgentMessage) -> some View {
        switch msg.role {
        case .user:
            HStack { Spacer(minLength: 24); bubble(msg.text, color: theme.userBubble) }
        case .assistant:
            HStack { bubble(msg.text, color: theme.assistantBubble); Spacer(minLength: 24) }
        case .system:
            Text(msg.text)
                .font(theme.monoFont)
                .foregroundStyle(theme.foreground.opacity(0.7))
                .padding(.vertical, 2)
        case .error:
            Text(msg.text)
                .font(theme.monoFont)
                .foregroundStyle(theme.errorColor)
                .padding(8)
                .background(theme.errorColor.opacity(0.08))
                .cornerRadius(6)
        }
    }

    private func bubble(_ text: String, color: Color) -> some View {
        Text(text)
            .font(theme.monoFont)
            .padding(10)
            .background(color)
            .cornerRadius(10)
            .textSelection(.enabled)
    }

    private var input: some View {
        HStack {
            TextField("Ask Rocky…", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .font(theme.monoFont)
                .onSubmit { Task { await viewModel.submit() } }
                .disabled(viewModel.inputDisabled)
            if viewModel.isBusy {
                ProgressView().scaleEffect(0.6)
            } else {
                Button {
                    Task { await viewModel.submit() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: [])
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(10)
    }
}

//
//  InboxView.swift
//  Methods
//
//  Message threads with brands, plus the official PaidPost thread.
//

import SwiftUI

struct InboxView: View {
    @State private var threads: [ThreadDTO] = []
    @State private var isLoading = true
    @State private var loadFailed = false

    var body: some View {
        Group {
            if isLoading && threads.isEmpty {
                ProgressView().tint(Theme.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if threads.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(threads) { thread in
                        NavigationLink(value: thread) {
                            ThreadRow(thread: thread)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable { await load() }
            }
        }
        .background(Theme.background)
        .navigationTitle("Messages")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationDestination(for: ThreadDTO.self) { thread in
            ThreadView(thread: thread)
        }
        .task { await load() }
    }

    private func load() async {
        loadFailed = false
        do {
            threads = try await InboxAPI.fetchInbox()
        } catch {
            loadFailed = true
        }
        isLoading = false
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: loadFailed ? "wifi.slash" : "bubble.left.and.bubble.right.fill")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Theme.textTertiary)
            Text(loadFailed ? "Couldn't load messages" : "No messages yet")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text(loadFailed
                 ? "Pull down or come back later."
                 : "When brands message you about campaigns, the conversation shows up here.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
}

private struct ThreadRow: View {
    let thread: ThreadDTO

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Theme.electric.opacity(0.15))
                if let logo = thread.brand_logo, let url = URL(string: logo) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        initialsView
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(.circle)
                } else {
                    initialsView
                }
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(thread.displayName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    if let at = BackendDate.parse(thread.last_message_at) {
                        Text(at.relativeFormatted)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                HStack {
                    Text((thread.last_sender_was_me == true ? "You: " : "") + thread.last_message_body)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                    Spacer()
                    if let unread = thread.unread_count, unread > 0 {
                        Text("\(unread)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.background)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Theme.accent)
                            .clipShape(.capsule)
                    }
                }
            }
        }
        .padding(12)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.stroke, lineWidth: 1))
    }

    private var initialsView: some View {
        Text(String(thread.displayName.prefix(1)).uppercased())
            .font(.system(size: 18, weight: .heavy, design: .rounded))
            .foregroundStyle(Theme.electric)
    }
}

// MARK: - Conversation

struct ThreadView: View {
    let thread: ThreadDTO

    @State private var messages: [MessageDTO] = []
    @State private var draft = ""
    @State private var sending = false
    @State private var sendError: String?
    @State private var myUserId: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(messages) { message in
                            MessageBubble(message: message, isMine: isMine(message))
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onChange(of: messages.count) {
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            composer
        }
        .background(Theme.background)
        .navigationTitle(thread.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            myUserId = await APIClient.shared.currentUserId
            messages = (try? await InboxAPI.fetchThread(thread.threadKey)) ?? []
            await InboxAPI.markThreadRead(thread.threadKey)
        }
    }

    private func isMine(_ message: MessageDTO) -> Bool {
        guard let sender = message.sender_user_id, let mine = myUserId else { return false }
        return sender == mine
    }

    private var composer: some View {
        VStack(spacing: 6) {
            if let sendError {
                Text(sendError)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.coral)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
            }
            composerBar
        }
    }

    private var composerBar: some View {
        HStack(spacing: 10) {
            TextField("Message…", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Theme.surface)
                .clipShape(.rect(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.stroke, lineWidth: 1))

            Button {
                Task { await send() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(canSend ? Theme.accent : Theme.textTertiary)
            }
            .disabled(!canSend || sending)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        sending = true
        sendError = nil
        defer { sending = false }
        do {
            try await InboxAPI.sendMessage(thread.threadKey, body: text)
            draft = ""
            messages = (try? await InboxAPI.fetchThread(thread.threadKey)) ?? messages
        } catch {
            // Keep the draft so the user can retry, but tell them it failed.
            sendError = (error as? APIError)?.errorDescription ?? "Couldn't send. Tap to retry."
        }
    }
}

private struct MessageBubble: View {
    let message: MessageDTO
    let isMine: Bool

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 48) }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                Text(message.body)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isMine ? Theme.background : Theme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isMine ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.surfaceElevated))
                    .clipShape(.rect(cornerRadius: 16))
                if let at = BackendDate.parse(message.created_at) {
                    Text(at.relativeFormatted)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            if !isMine { Spacer(minLength: 48) }
        }
    }
}

#Preview {
    NavigationStack { InboxView() }
        .environment(AppStore())
        .preferredColorScheme(.dark)
}

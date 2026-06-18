//
//  NotificationsView.swift
//  Methods
//

import SwiftUI

struct NotificationsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if store.notifications.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(store.notifications) { notification in
                        NotificationRow(notification: notification)
                            .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing) {
                                // Mark-read is one-way; only offer it on unread
                                // items so the affordance isn't misleading.
                                if !notification.isRead {
                                    Button {
                                        withAnimation {
                                            store.markNotificationRead(notification)
                                        }
                                    } label: {
                                        Label("Mark read", systemImage: "envelope.open.fill")
                                    }
                                    .tint(notification.type.color)
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Theme.background)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if store.unreadNotificationCount > 0 {
                    Button("Mark all read") {
                        withAnimation {
                            store.markAllNotificationsRead()
                        }
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Theme.textTertiary)
            Text("No notifications yet")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text("When brands approve your applications or send payouts, you'll see them here.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
}

private struct NotificationRow: View {
    @Environment(AppStore.self) private var store
    let notification: Notification

    var body: some View {
        Button {
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.impactOccurred()
            withAnimation {
                store.markNotificationRead(notification)
            }
        } label: {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(notification.type.color.opacity(0.15))
                        .frame(width: 42, height: 42)

                    Image(systemName: notification.type.icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(notification.type.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(notification.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(notification.isRead ? Theme.textSecondary : Theme.textPrimary)

                        if !notification.isRead {
                            Circle()
                                .fill(Theme.accent)
                                .frame(width: 8, height: 8)
                        }
                    }

                    Text(notification.body)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)

                    Text(notification.timestamp.relativeFormatted)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }

                Spacer()
            }
            .padding(14)
            .background(notification.isRead ? Theme.surface : Theme.surfaceElevated)
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

extension Date {
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
    }
    .environment(AppStore())
    .preferredColorScheme(.dark)
}

//
//  TodaysTasksCard.swift
//  Methods
//
//  Home-screen card surfacing the creator's next actions (sign contract,
//  upload videos), plus the campaigns list. Tasks are derived in AppStore.
//

import SwiftUI

/// An actionable item shown on the home tab.
struct CreatorTask: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let kind: Kind

    enum Kind: Hashable {
        case contract(applicationId: String, brand: String)
        case workspace(brandSlug: String)
    }
}

/// Card listing the creator's current to-dos. Hidden when there are none.
struct TodaysTasksCard: View {
    @Environment(AppStore.self) private var store
    @Binding var path: [DiscoverRoute]
    @State private var contractTask: CreatorTask?

    var body: some View {
        let tasks = store.todaysTasks
        if !tasks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "checklist")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.gold)
                    Text("Today's tasks")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                }
                ForEach(tasks) { task in
                    Button {
                        handle(task)
                    } label: {
                        taskRow(task)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .sheet(item: $contractTask) { task in
                if case let .contract(applicationId, brand) = task.kind {
                    ContractView(applicationId: applicationId, brand: brand) {
                        Task { await store.loadApplications() }
                    }
                }
            }
        }
    }

    private func handle(_ task: CreatorTask) {
        switch task.kind {
        case .contract:
            contractTask = task
        case .workspace(let slug):
            path.append(.workspace(brandSlug: slug))
        }
    }

    private func taskRow(_ task: CreatorTask) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Theme.gold.opacity(0.15)).frame(width: 40, height: 40)
                Image(systemName: task.icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.gold)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(task.subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(14)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.stroke, lineWidth: 1))
    }
}

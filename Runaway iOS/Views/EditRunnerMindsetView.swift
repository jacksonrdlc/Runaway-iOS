// Runaway iOS/Views/EditRunnerMindsetView.swift
import SwiftUI

struct EditRunnerMindsetView: View {
    let athleteId: Int
    let existing: MindsetProfile?
    let onSave: (MindsetProfile) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var whyIRun: String = ""
    @State private var selectedValues: [String] = []
    @State private var isSaving = false
    @State private var saveError: String? = nil

    private let presetValues = [
        "consistency", "mental health", "stress relief", "community",
        "competition", "adventure", "fitness", "routine", "solitude", "speed"
    ]

    private var canSave: Bool {
        whyIRun.trimmingCharacters(in: .whitespaces).count >= 10 && !selectedValues.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.DarkMode.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {

                        if let error = saveError {
                            Text(error)
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(AppTheme.Colors.error)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppTheme.Colors.errorBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        // WHY I RUN
                        VStack(alignment: .leading, spacing: 10) {
                            EyebrowLabel(text: "WHY I RUN")
                            ZStack(alignment: .topLeading) {
                                if whyIRun.isEmpty {
                                    Text("I run to clear my head and feel strong")
                                        .font(.system(size: 15, design: .rounded))
                                        .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
                                        .padding(.horizontal, 12)
                                        .padding(.top, 12)
                                }
                                TextEditor(text: $whyIRun)
                                    .font(.system(size: 15, design: .rounded))
                                    .foregroundColor(.white)
                                    .scrollContentBackground(.hidden)
                                    .padding(8)
                                    .frame(minHeight: 100)
                                    .onChange(of: whyIRun) { _, newValue in
                                        if newValue.count > 200 {
                                            whyIRun = String(newValue.prefix(200))
                                        }
                                    }
                            }
                            .background(AppTheme.Colors.DarkMode.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))

                            Text("\(whyIRun.count)/200")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }

                        // WHAT MATTERS MOST
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                EyebrowLabel(text: "WHAT MATTERS MOST")
                                Spacer()
                                Text("Pick up to 3")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
                            }
                            ValueChipGrid(
                                values: presetValues,
                                selected: $selectedValues,
                                maxSelected: 3
                            )
                        }

                        // Save button
                        Button {
                            Task { await handleSave() }
                        } label: {
                            HStack {
                                if isSaving {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.black)
                                        .scaleEffect(0.85)
                                } else {
                                    Text("Save")
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(canSave && !isSaving
                                ? AppTheme.Colors.warmAmber
                                : AppTheme.Colors.warmAmber.opacity(0.3))
                            .foregroundColor(canSave && !isSaving ? .black : .black.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(!canSave || isSaving)

                    }
                    .padding(20)
                }
            }
            .navigationTitle("Running Mindset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.Colors.warmAmber)
                }
            }
        }
        .onAppear {
            if let existing {
                whyIRun = existing.whyIRun
                selectedValues = existing.coreValues
            }
        }
    }

    private func handleSave() async {
        isSaving = true
        saveError = nil
        do {
            let profile = try await RunnerMindsetService.saveProfile(
                athleteId: athleteId,
                whyIRun: whyIRun.trimmingCharacters(in: .whitespaces),
                coreValues: selectedValues
            )
            await MainActor.run {
                onSave(profile)
                dismiss()
            }
        } catch {
            await MainActor.run {
                isSaving = false
                saveError = "Couldn't save — try again"
            }
        }
    }
}

// MARK: - Value Chip Grid

private struct ValueChipGrid: View {
    let values: [String]
    @Binding var selected: [String]
    let maxSelected: Int

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(values, id: \.self) { value in
                let isSelected = selected.contains(value)
                Button {
                    toggleValue(value)
                } label: {
                    Text(isSelected ? "✓ \(value)" : value)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular, design: .rounded))
                        .foregroundColor(isSelected ? AppTheme.Colors.warmAmber : AppTheme.Colors.DarkMode.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(isSelected
                            ? AppTheme.Colors.warmAmber.opacity(0.12)
                            : AppTheme.Colors.DarkMode.cardBackground)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(
                                isSelected ? AppTheme.Colors.warmAmber : Color.white.opacity(0.12),
                                lineWidth: 1
                            )
                        )
                }
            }
        }
    }

    private func toggleValue(_ value: String) {
        if let index = selected.firstIndex(of: value) {
            selected.remove(at: index)
        } else if selected.count < maxSelected {
            selected.append(value)
        } else {
            selected.removeFirst()
            selected.append(value)
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.map { $0.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0 }.reduce(0, +)
            + CGFloat(max(rows.count - 1, 0)) * spacing
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: ProposedViewSize(width: bounds.width, height: nil), subviews: subviews)
        var y = bounds.minY
        for row in rows {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            var x = bounds.minX
            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubview]] {
        var rows: [[LayoutSubview]] = [[]]
        var rowWidth: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth && !rows[rows.count - 1].isEmpty {
                rows.append([])
                rowWidth = 0
            }
            rows[rows.count - 1].append(subview)
            rowWidth += size.width + spacing
        }
        return rows
    }
}

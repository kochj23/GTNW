//
//  AdministrationSelectionView.swift
//  Global Thermal Nuclear War
//
//  Selector for historical US presidential administrations (1945-2025)
//

import SwiftUI

struct AdministrationSelectionView: View {
    @Binding var selectedAdministration: Administration?
    @Environment(\.dismiss) var dismiss

    private let administrations = Advisor.allAdministrations()

    var body: some View {
        ZStack {
            AppSettings.terminalBackground
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Header
                VStack(spacing: 10) {
                    Text("SELECT PRESIDENTIAL ADMINISTRATION")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(AppSettings.terminalAmber)

                    Text("Nuclear Age: 1945-Present")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(AppSettings.terminalGreen)
                }
                .padding(.top, 20)

                Divider()
                    .background(AppSettings.terminalGreen)

                // Administration list
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(administrations.reversed()) { admin in
                            Button(action: {
                                selectedAdministration = admin
                                dismiss()
                            }) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(admin.president)
                                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                                .foregroundColor(AppSettings.terminalGreen)

                                            Text(admin.years)
                                                .font(.system(size: 14, design: .monospaced))
                                                .foregroundColor(AppSettings.terminalAmber)
                                        }

                                        Spacer()

                                        Text(admin.party)
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundColor(admin.party == "Republican" ? .red : .blue)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.white.opacity(0.1))
                                            .cornerRadius(4)
                                    }

                                    // Key advisors preview
                                    Text("\(admin.advisors.count) advisors including \(admin.advisors.prefix(3).map { $0.title }.joined(separator: ", "))")
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(AppSettings.terminalGreen.opacity(0.7))
                                        .lineLimit(2)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(selectedAdministration?.id == admin.id ? AppSettings.terminalGreen.opacity(0.15) : Color.clear)
                                .border(AppSettings.terminalGreen, width: 1)
                            }
                        }
                    }
                    .padding()
                }

                Divider()
                    .background(AppSettings.terminalGreen)

                // Bottom buttons
                HStack(spacing: 20) {
                    Button(action: {
                        selectedAdministration = nil
                        dismiss()
                    }) {
                        Text("USE DEFAULT (Trump 2025)")
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundColor(AppSettings.terminalBackground)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(AppSettings.terminalAmber)
                    }

                    Button(action: {
                        dismiss()
                    }) {
                        Text("CANCEL")
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundColor(AppSettings.terminalGreen)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .border(AppSettings.terminalGreen, width: 1)
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 600, minHeight: 700)
    }
}

#Preview {
    AdministrationSelectionView(selectedAdministration: .constant(nil))
}

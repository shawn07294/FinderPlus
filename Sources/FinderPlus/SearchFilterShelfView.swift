import SwiftUI

public struct SearchFilterShelfView: View {
    @ObservedObject var viewModel: ExplorerViewModel

    public var body: some View {
        VStack(spacing: 8) {
            // Row 1: Scope & Target Controls
            HStack(spacing: 16) {
                // Search Scope
                HStack(spacing: 6) {
                    Text("Search:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Picker("Scope", selection: $viewModel.searchParameters.scope) {
                        Text("\"\(viewModel.currentDirectory.lastPathComponent)\" (This Folder)")
                            .tag(SearchScope.currentFolderOnly)
                        Text("Subfolders")
                            .tag(SearchScope.currentFolderAndSubfolders)
                        Text("This Mac")
                            .tag(SearchScope.entireMac)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 360)
                }

                Divider()
                    .frame(height: 18)

                // Search Target (Name vs Content)
                Picker("Target", selection: $viewModel.searchParameters.searchTarget) {
                    ForEach(SearchTarget.allCases) { target in
                        Text(target.rawValue).tag(target)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)

                Divider()
                    .frame(height: 18)

                // Match Mode
                Picker("Mode", selection: $viewModel.searchParameters.matchMode) {
                    ForEach(MatchMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 190)

                Spacer()

                // Case Sensitive & Hidden Toggles
                Toggle(isOn: $viewModel.searchParameters.isCaseSensitive) {
                    Text("Aa")
                        .font(.system(.body, design: .monospaced).bold())
                }
                .toggleStyle(.button)
                .help("Case Sensitive")

                Toggle(isOn: $viewModel.searchParameters.includeHiddenFiles) {
                    Image(systemName: "eye")
                }
                .toggleStyle(.button)
                .help("Include Hidden Files")
            }

            // Row 2: Secondary Filters (Kind, Date, Size) & Live Status
            HStack(spacing: 12) {
                // Kind Menu
                Menu {
                    ForEach(KindFilter.allCases) { kind in
                        Button(action: { viewModel.searchParameters.kindFilter = kind }) {
                            HStack {
                                Text(kind.rawValue)
                                if viewModel.searchParameters.kindFilter == kind {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Label(viewModel.searchParameters.kindFilter.rawValue, systemImage: "folder.badge.gearshape")
                        .font(.caption)
                }
                .menuStyle(.borderedButton)

                // Date Modified Menu
                Menu {
                    ForEach(DateFilter.allCases) { date in
                        Button(action: { viewModel.searchParameters.dateFilter = date }) {
                            HStack {
                                Text(date.rawValue)
                                if viewModel.searchParameters.dateFilter == date {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Label(viewModel.searchParameters.dateFilter.rawValue, systemImage: "calendar")
                        .font(.caption)
                }
                .menuStyle(.borderedButton)

                // Size Menu
                Menu {
                    ForEach(SizeFilter.allCases) { size in
                        Button(action: { viewModel.searchParameters.sizeFilter = size }) {
                            HStack {
                                Text(size.rawValue)
                                if viewModel.searchParameters.sizeFilter == size {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Label(viewModel.searchParameters.sizeFilter.rawValue, systemImage: "scalemass")
                        .font(.caption)
                }
                .menuStyle(.borderedButton)

                if hasNonDefaultFilters {
                    Button(action: resetFilters) {
                        Text("Reset Filters")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                }

                Spacer()

                // Progress & Count Indicator
                if viewModel.isSearching {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 14, height: 14)
                        Text("Scanned \(viewModel.scannedCount) items...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("Cancel") {
                            viewModel.cancelSearch()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                } else if viewModel.isSearchActive {
                    Text("\(viewModel.searchResults.count) results found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.75))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(NSColor.separatorColor)),
            alignment: .bottom
        )
    }

    private var hasNonDefaultFilters: Bool {
        viewModel.searchParameters.kindFilter != .any ||
        viewModel.searchParameters.dateFilter != .any ||
        viewModel.searchParameters.sizeFilter != .any ||
        viewModel.searchParameters.isCaseSensitive ||
        viewModel.searchParameters.includeHiddenFiles ||
        viewModel.searchParameters.matchMode != .contains ||
        viewModel.searchParameters.searchTarget != .fileName
    }

    private func resetFilters() {
        let currentScope = viewModel.searchParameters.scope
        viewModel.searchParameters = SearchParameters()
        viewModel.searchParameters.scope = currentScope
    }
}

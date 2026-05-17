import SwiftUI
import PhotosUI

struct ContentView: View {
    @StateObject private var vm = EditorViewModel()

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                TopBar(vm: vm)
                Divider().overlay(Theme.border)

                CanvasView(vm: vm)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider().overlay(Theme.border)
                TabBar(vm: vm)
                BottomPanel(vm: vm)
            }
        }
        .onChange(of: vm.photoPickerItem) { _ in vm.loadPickedPhoto() }
    }
}

// MARK: - Top Bar
struct TopBar: View {
    @ObservedObject var vm: EditorViewModel
    @State private var showExportSheet = false

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 0) {
                Text("Lens")
                    .font(.custom("Georgia", size: 20))
                    .foregroundColor(Theme.accent)
                Text("Lab")
                    .font(.custom("Georgia-Italic", size: 20))
                    .foregroundColor(Theme.accentDark)
            }

            Spacer()

            PhotosPicker(selection: $vm.photoPickerItem, matching: .images) {
                Text("IMPORT")
                    .font(.monoSmall)
                    .kerning(1)
                    .foregroundColor(Theme.muted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Theme.bg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                    .cornerRadius(6)
            }

            Button {
                showExportSheet = true
            } label: {
                HStack(spacing: 4) {
                    Text("Export")
                        .font(.monoSmall)
                        .kerning(1)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundColor(Theme.surface)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Theme.accent)
                .cornerRadius(6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.surface)
        .overlay(Divider().overlay(Theme.border), alignment: .bottom)
        .sheet(isPresented: $showExportSheet) {
            if let img = vm.renderedImage {
                ShareSheet(items: [img])
            }
        }
    }
}

// MARK: - Canvas
struct CanvasView: View {
    @ObservedObject var vm: EditorViewModel

    var body: some View {
        ZStack {
            Theme.canvasBg

            if let img = vm.renderedImage {
                if vm.showBeforeAfter, let original = vm.photo {
                    BeforeAfterView(before: original, after: img)
                        .padding(20)
                } else {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(20)
                        .shadow(color: Color(hex: "#7A5A14").opacity(0.18), radius: 20, x: 0, y: 8)
                        .transition(.opacity.animation(.easeInOut(duration: 0.25)))
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "photo")
                        .font(.system(size: 36, weight: .thin))
                        .foregroundColor(Theme.muted)
                    Text("Tap Import to get started")
                        .font(.monoSmall)
                        .foregroundColor(Theme.muted)
                }
            }

            if let _ = vm.renderedImage {
                VStack {
                    Spacer()
                    Text(vm.activeFilter.name.uppercased())
                        .font(.monoTiny)
                        .kerning(1.5)
                        .foregroundColor(Theme.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(Theme.surface.opacity(0.88))
                        .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
                        .clipShape(Capsule())
                        .padding(.bottom, 12)
                }
            }

            if vm.isProcessing {
                Color.black.opacity(0.04)
                ProgressView().tint(Theme.accent)
            }
        }
    }
}

// MARK: - Before/After
struct BeforeAfterView: View {
    let before: UIImage
    let after: UIImage
    @State private var dividerX: CGFloat = 0.5

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Image(uiImage: after)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geo.size.width, height: geo.size.height)

                Image(uiImage: before)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .mask(
                        HStack(spacing: 0) {
                            Color.black.frame(width: geo.size.width * dividerX)
                            Color.clear
                        }
                    )

                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: 2)
                    .offset(x: geo.size.width * dividerX - 1)

                Circle()
                    .fill(Theme.accent)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "arrow.left.and.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .offset(x: geo.size.width * dividerX - 14, y: geo.size.height / 2 - 14)
                    .gesture(
                        DragGesture()
                            .onChanged { v in
                                let x = v.location.x / geo.size.width
                                dividerX = min(max(x, 0.05), 0.95)
                            }
                    )
            }
            .onAppear { dividerX = 0.5 }
        }
    }
}

// MARK: - Tab Bar
struct TabBar: View {
    @ObservedObject var vm: EditorViewModel

    var body: some View {
        HStack(spacing: 0) {
            ForEach(EditorViewModel.EditorTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        vm.activeTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 16, weight: vm.activeTab == tab ? .semibold : .regular))
                        Text(tab.rawValue.uppercased())
                            .font(.monoTiny)
                            .kerning(0.8)
                    }
                    .foregroundColor(vm.activeTab == tab ? Theme.accent : Theme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .overlay(
                        Rectangle()
                            .fill(Theme.accent)
                            .frame(height: 2),
                        alignment: .top
                    )
                    .opacity(vm.activeTab == tab ? 1 : 0.6)
                    .animation(.easeInOut(duration: 0.18), value: vm.activeTab)
                }
            }
        }
        .background(Theme.surface)
        .overlay(Divider().overlay(Theme.border), alignment: .top)
    }
}

// MARK: - Bottom Panel
struct BottomPanel: View {
    @ObservedObject var vm: EditorViewModel

    var body: some View {
        Group {
            switch vm.activeTab {
            case .filters:
                FilterStripPanel(vm: vm)
            case .adjust, .detail:
                AdjustmentPanel(vm: vm)
            }
        }
        .background(Theme.panel)
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

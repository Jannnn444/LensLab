import SwiftUI

// MARK: - Filter Strip Panel
struct FilterStripPanel: View {
    @ObservedObject var vm: EditorViewModel
    @State private var thumbnails: [Int: UIImage] = [:]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(vm.filters.indices, id: \.self) { i in
                    FilterPill(
                        filter: vm.filters[i],
                        thumbnail: thumbnails[i],
                        isActive: vm.activeFilterIndex == i
                    ) {
                        vm.selectFilter(i)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .onAppear { generateThumbnails() }
        .onChange(of: vm.activePhotoIndex) { _ in generateThumbnails() }
    }

    func generateThumbnails() {
        let photo = vm.activePhoto
        for (i, filter) in vm.filters.enumerated() {
            Task.detached(priority: .background) {
                guard let ci = CIImage(image: photo) else { return }
                let filtered = filter.apply(ci)
                let thumb = FilterEngine.render(filtered, size: CGSize(width: 120, height: 120))
                await MainActor.run { thumbnails[i] = thumb }
            }
        }
    }
}

struct FilterPill: View {
    let filter: PhotoFilter
    let thumbnail: UIImage?
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Group {
                    if let img = thumbnail {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Theme.border.opacity(0.4))
                            .overlay(ProgressView().scaleEffect(0.6).tint(Theme.muted))
                    }
                }
                .frame(width: 62, height: 62)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isActive ? Theme.accent : Color.clear, lineWidth: 2)
                )
                .shadow(color: Theme.accentDark.opacity(isActive ? 0.25 : 0),
                        radius: 6, x: 0, y: 3)

                Text(filter.name.uppercased())
                    .font(.monoTiny)
                    .kerning(0.5)
                    .foregroundColor(isActive ? Theme.accent : Theme.muted)
                    .lineLimit(1)
                    .frame(width: 66)
            }
            .scaleEffect(isActive ? 1.04 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isActive)
        }
    }
}

// MARK: - Adjustment Panel
struct AdjustmentPanel: View {
    @ObservedObject var vm: EditorViewModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(vm.activeSectionsForTab) { section in
                    AdjustmentSectionView(section: section, vm: vm)
                    Divider().overlay(Theme.border)
                }
            }
        }
        .frame(maxHeight: 280)
    }
}

struct AdjustmentSectionView: View {
    let section: AdjustmentSection
    @ObservedObject var vm: EditorViewModel

    var body: some View {
        VStack(spacing: 12) {
            // Section header
            HStack {
                Text(section.title.uppercased())
                    .font(.monoSmall)
                    .kerning(1.2)
                    .foregroundColor(Theme.muted)
                Spacer()
                Button {
                    vm.resetSection(section.id)
                } label: {
                    Text("RESET")
                        .font(.monoTiny)
                        .kerning(0.8)
                        .foregroundColor(Theme.muted)
                }
            }

            ForEach(section.sliders) { slider in
                SliderRow(slider: slider, sectionId: section.id, vm: vm)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Slider Row
struct SliderRow: View {
    let slider: AdjustmentSlider
    let sectionId: String
    @ObservedObject var vm: EditorViewModel

    @State private var localValue: Float = 0

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(slider.label.uppercased())
                    .font(.monoTiny)
                    .kerning(0.6)
                    .foregroundColor(Theme.muted)
                Spacer()
                Text(String(Int(localValue)))
                    .font(.monoTiny)
                    .foregroundColor(localValue == 0 ? Theme.muted : Theme.text)
                    .monospacedDigit()
                    .frame(width: 32, alignment: .trailing)
            }

            HStack(spacing: 10) {
                // Center dot indicator
                Circle()
                    .fill(localValue == 0 ? Theme.border : Theme.accent)
                    .frame(width: 4, height: 4)

                Slider(value: $localValue, in: Float(Double(slider.min))...Float(Double(slider.max)))
                    .tint(Theme.accent)
                    .onChange(of: localValue) { v in
                        vm.updateSlider(sectionId: sectionId,
                                        sliderId: slider.id,
                                        value: v)
                    }
            }
        }
        .onAppear {
            // Sync with vm value
            for s in vm.adjustmentSections where s.id == sectionId {
                for sl in s.sliders where sl.id == slider.id {
                    localValue = sl.value
                }
            }
        }
        .onChange(of: vm.adjustmentSections) { sections in
            for s in sections where s.id == sectionId {
                for sl in s.sliders where sl.id == slider.id {
                    if localValue != sl.value { localValue = sl.value }
                }
            }
        }
    }
}

// MARK: - AdjustmentSection Equatable for onChange
extension AdjustmentSection: Equatable {
    static func == (lhs: AdjustmentSection, rhs: AdjustmentSection) -> Bool {
        lhs.id == rhs.id && lhs.sliders == rhs.sliders
    }
}

extension AdjustmentSlider: Equatable {
    static func == (lhs: AdjustmentSlider, rhs: AdjustmentSlider) -> Bool {
        lhs.id == rhs.id && lhs.value == rhs.value
    }
}

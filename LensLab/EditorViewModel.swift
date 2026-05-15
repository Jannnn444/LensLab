import SwiftUI
import CoreImage
import PhotosUI

@MainActor
class EditorViewModel: ObservableObject {

    // MARK: - Photos
    @Published var photos: [UIImage] = []
    @Published var activePhotoIndex: Int = 0

    // MARK: - Filter
    @Published var activeFilterIndex: Int = 0
    let filters = FilterEngine.filters

    // MARK: - Adjustments
    @Published var adjustmentSections: [AdjustmentSection] = AdjustmentSection.defaults

    // MARK: - UI State
    @Published var activeTab: EditorTab = .filters
    @Published var showBeforeAfter: Bool = false
    @Published var isProcessing: Bool = false
    @Published var renderedImage: UIImage?
    @Published var photoPickerItem: PhotosPickerItem?

    enum EditorTab: String, CaseIterable {
        case filters = "Filters"
        case adjust  = "Adjust"
        case detail  = "Detail"

        var icon: String {
            switch self {
            case .filters: return "camera.filters"
            case .adjust:  return "slider.horizontal.3"
            case .detail:  return "wand.and.stars"
            }
        }
    }

    // MARK: - Init
    init() {
        // Generate 6 placeholder photos
        for i in 0..<6 {
            photos.append(FilterEngine.generatePlaceholder(seed: i * 37 + 11,
                                                           size: CGSize(width: 800, height: 600)))
        }
        processImage()
    }

    // MARK: - Computed
    var activePhoto: UIImage { photos[activePhotoIndex] }

    var activeFilter: PhotoFilter { filters[activeFilterIndex] }

    var activeSectionsForTab: [AdjustmentSection] {
        switch activeTab {
        case .filters: return []
        case .adjust:  return adjustmentSections.filter { $0.id == "light" || $0.id == "color" }
        case .detail:  return adjustmentSections.filter { $0.id == "detail" }
        }
    }

    // MARK: - Actions
    func selectPhoto(_ index: Int) {
        activePhotoIndex = index
        processImage()
    }

    func selectFilter(_ index: Int) {
        activeFilterIndex = index
        processImage()
    }

    func updateSlider(sectionId: String, sliderId: String, value: Float) {
        guard let si = adjustmentSections.firstIndex(where: { $0.id == sectionId }),
              let li = adjustmentSections[si].sliders.firstIndex(where: { $0.id == sliderId })
        else { return }
        adjustmentSections[si].sliders[li].value = value
        processImage()
    }

    func resetSection(_ sectionId: String) {
        guard let si = adjustmentSections.firstIndex(where: { $0.id == sectionId }) else { return }
        let defaults = AdjustmentSection.defaults
        if let di = defaults.firstIndex(where: { $0.id == sectionId }) {
            adjustmentSections[si].sliders = defaults[di].sliders
        }
        processImage()
    }

    func processImage() {
        isProcessing = true
        let photo = activePhoto
        let filter = activeFilter
        let sections = adjustmentSections

        Task.detached(priority: .userInitiated) {
            guard let ci = CIImage(image: photo) else { return }
            let filtered = filter.apply(ci)
            let adjusted = FilterEngine.applyAdjustments(filtered, sections: sections)
            let out = FilterEngine.render(adjusted, size: CGSize(width: 1200, height: 900))
            await MainActor.run {
                self.renderedImage = out ?? photo
                self.isProcessing = false
            }
        }
    }

    func loadPickedPhoto() {
        guard let item = photoPickerItem else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                photos.insert(img, at: 0)
                activePhotoIndex = 0
                processImage()
            }
        }
    }
}

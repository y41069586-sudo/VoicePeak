import SwiftUI
import SwiftData
import UIKit

/// Preview + share for a passed half-face test's Verified Reveal. Renders the
/// card on-device and shares a story-sized PNG.
struct VerifiedShareView: View {
    let test: HalfFaceTest

    @Query private var scans: [Scan]
    @Query private var products: [Product]
    @Query private var profiles: [UserProfile]

    @State private var renderedImage: UIImage?
    @State private var shareURL: URL?

    private var product: Product? { products.first { $0.id == test.productID } }

    private var progress: TestProgress {
        let context = SkinContext.build(scans: scans.filter { $0.side == .full }, profile: profiles.first)
        return HalfFaceTestScoring.progress(for: test, scans: scans, product: product, context: context)
    }

    private var faceImage: UIImage? {
        HalfFaceTestScoring.testScans(test, in: scans)
            .sorted { $0.date < $1.date }
            .last?.thumbnailFilename
            .flatMap { ThumbnailStore.load($0) }
    }

    private var card: VerifiedShareCard {
        VerifiedShareCard(
            productName: product?.name ?? Brand.name,
            treatedSide: test.testSide,
            focus: progress.focus,
            treatedImprovement: progress.treatedFocus?.improvement ?? 0,
            controlImprovement: progress.controlFocus?.improvement ?? 0,
            image: faceImage,
            date: .now
        )
    }

    var body: some View {
        ZStack {
            GradientMeshBackground()
            VStack(spacing: 16) {
                ScrollView {
                    Group {
                        if let renderedImage {
                            Image(uiImage: renderedImage)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                        } else {
                            ProgressView().padding(60)
                        }
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)

                if let shareURL {
                    ShareLink(item: shareURL) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                            Text("share.button")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.signature, in: Capsule())
                        .blueGlow(Theme.primary, radius: 22, opacity: 0.45)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationTitle("share.title")
        .navigationBarTitleDisplayMode(.inline)
        .task { renderCard() }
    }

    private func renderCard() {
        guard renderedImage == nil else { return }
        guard let image = ShareRenderer.image(for: card, size: VerifiedShareCard.size) else { return }
        renderedImage = image
        shareURL = ShareRenderer.pngURL(for: image)
    }
}

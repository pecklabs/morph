import SwiftUI

struct DropZoneView: View {
    @Environment(AppModel.self) private var model
    @Environment(Localizer.self) private var loc
    var isTargeted: Bool

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: model.mode == .makePDF ? Theme.pdfGlow : Theme.convertGlow,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 148, height: 126)
                    .blur(radius: 28)
                    .opacity(isTargeted ? 0.42 : 0.26)
                    .animation(.easeOut(duration: 0.25), value: isTargeted)

                Image(model.mode == .makePDF ? "IllustrationPDF" : "IllustrationConvert")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 132, height: 132)
                    .scaleEffect(isTargeted ? 1.06 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isTargeted)
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 6)
            }

            VStack(spacing: 6) {
                Text(loc.t(model.mode == .makePDF ? "drop.title.pdf" : "drop.title"))
                    .font(.title2.weight(.semibold))
                Text(loc.t(model.mode == .makePDF ? "drop.subtitle.pdf" : "drop.subtitle"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Button {
                model.presentOpenPanel()
            } label: {
                Text(loc.t("drop.choose"))
                    .padding(.horizontal, 6)
            }
            .controlSize(.large)
            .primaryActionStyle(tint: Theme.accent)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }
}

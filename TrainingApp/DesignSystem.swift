import SwiftUI

extension Color {
    static let appAccent = Color(red: 0.8, green: 48.0 / 255.0, blue: 0.0)
}

enum AppUI {
    enum Spacing {
        static let xSmall: CGFloat = 6
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let regular: CGFloat = 14
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 20
        static let screenHorizontal: CGFloat = 16
        static let screenBottom: CGFloat = 12
    }

    enum CornerRadius {
        static let small: CGFloat = 10
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 24
    }

    enum Stroke {
        static let hairline: CGFloat = 1
        static let strong: CGFloat = 1.2
    }

    enum Shadow {
        static let radius: CGFloat = 10
        static let y: CGFloat = 6
        static let opacity: CGFloat = 0.22
    }

    enum Metrics {
        static let minimumHitTarget: CGFloat = 44
    }
}

enum AppCardTone {
    case regular
    case subtle
    case emphasized
}

struct AppCard<Content: View>: View {
    private let tone: AppCardTone
    private let padding: CGFloat
    private let content: Content

    init(
        tone: AppCardTone = .regular,
        padding: CGFloat = AppUI.Spacing.regular,
        @ViewBuilder content: () -> Content
    ) {
        self.tone = tone
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundShape.fill(fillStyle))
            .overlay(backgroundShape.strokeBorder(strokeColor, lineWidth: AppUI.Stroke.hairline))
            .shadow(color: .black.opacity(shadowOpacity), radius: AppUI.Shadow.radius, x: 0, y: AppUI.Shadow.y)
    }

    private var backgroundShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: AppUI.CornerRadius.large, style: .continuous)
    }

    private var fillStyle: AnyShapeStyle {
        switch tone {
        case .regular:
            return AnyShapeStyle(.ultraThinMaterial)
        case .subtle:
            return AnyShapeStyle(.thinMaterial)
        case .emphasized:
            return AnyShapeStyle(Color.white.opacity(0.08))
        }
    }

    private var strokeColor: Color {
        switch tone {
        case .regular:
            return Color.white.opacity(0.08)
        case .subtle:
            return Color.white.opacity(0.1)
        case .emphasized:
            return Color.white.opacity(0.12)
        }
    }

    private var shadowOpacity: CGFloat {
        switch tone {
        case .regular:
            return 0.16
        case .subtle:
            return 0.1
        case .emphasized:
            return AppUI.Shadow.opacity
        }
    }
}

struct StatChip: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    var accent: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: AppUI.Spacing.xSmall) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(.primary)

            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle((accent ?? .secondary).opacity(accent == nil ? 1 : 0.85))
            }
        }
        .padding(AppUI.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: AppUI.CornerRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppUI.CornerRadius.medium, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: AppUI.Stroke.hairline)
        )
    }
}

struct SectionHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    private let trailing: Trailing

    init(_ title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppUI.Spacing.medium) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
            trailing
        }
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: String, subtitle: String? = nil) {
        self.init(title, subtitle: subtitle) { EmptyView() }
    }
}

struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var isDisabled: Bool = false
    var role: ButtonRole? = nil
    var accessibilityLabelText: String? = nil
    var accessibilityHintText: String? = nil
    var action: () -> Void

    init(
        _ title: String,
        systemImage: String? = nil,
        isDisabled: Bool = false,
        role: ButtonRole? = nil,
        accessibilityLabelText: String? = nil,
        accessibilityHintText: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isDisabled = isDisabled
        self.role = role
        self.accessibilityLabelText = accessibilityLabelText
        self.accessibilityHintText = accessibilityHintText
        self.action = action
    }

    var body: some View {
        Button(role: role) {
            action()
        } label: {
            Group {
                if let systemImage {
                    Label(title, systemImage: systemImage)
                } else {
                    Text(title)
                }
            }
            .font(.headline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(minHeight: AppUI.Metrics.minimumHitTarget)
            .padding(.horizontal, AppUI.Spacing.medium)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: AppUI.CornerRadius.medium, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: AppUI.Stroke.hairline)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(role == .destructive ? Color.white : Color.white)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
        .modifier(
            ButtonAccessibilityModifier(
                label: accessibilityLabelText ?? title,
                hint: accessibilityHintText
            )
        )
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: AppUI.CornerRadius.medium, style: .continuous)
            .fill(backgroundStyle)
    }

    private var backgroundStyle: AnyShapeStyle {
        if role == .destructive {
            return AnyShapeStyle(Color.red)
        }
        return AnyShapeStyle(
            LinearGradient(
                colors: [Color.appAccent.opacity(0.95), Color.appAccent.opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

private struct ButtonAccessibilityModifier: ViewModifier {
    let label: String
    let hint: String?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let hint, !hint.isEmpty {
            content
                .accessibilityLabel(label)
                .accessibilityHint(hint)
        } else {
            content
                .accessibilityLabel(label)
        }
    }
}

struct AppRowStyle: ViewModifier {
    var horizontalPadding: CGFloat = AppUI.Spacing.medium
    var verticalPadding: CGFloat = AppUI.Spacing.small
    var cornerRadius: CGFloat = AppUI.CornerRadius.medium

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.09), lineWidth: AppUI.Stroke.hairline)
            )
    }
}

private struct AppCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppUI.Spacing.regular)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppUI.CornerRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppUI.CornerRadius.large, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: AppUI.Stroke.hairline)
            )
    }
}

private struct AppFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: AppUI.CornerRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppUI.CornerRadius.medium, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: AppUI.Stroke.hairline)
            )
    }
}

extension View {
    func appCardStyle() -> some View {
        modifier(AppCardModifier())
    }

    func appFieldStyle() -> some View {
        modifier(AppFieldModifier())
    }

    func appRowStyle(
        horizontalPadding: CGFloat = AppUI.Spacing.medium,
        verticalPadding: CGFloat = AppUI.Spacing.small,
        cornerRadius: CGFloat = AppUI.CornerRadius.medium
    ) -> some View {
        modifier(
            AppRowStyle(
                horizontalPadding: horizontalPadding,
                verticalPadding: verticalPadding,
                cornerRadius: cornerRadius
            )
        )
    }

    func appHitTarget() -> some View {
        frame(minHeight: AppUI.Metrics.minimumHitTarget)
    }

    func glassCard() -> some View {
        appCardStyle()
    }

    func glassField() -> some View {
        appFieldStyle()
    }
}

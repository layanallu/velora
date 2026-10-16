//
//  SessionExitOverlay.swift
//  Velora/UI/Component
//
//  Edge-to-edge exit confirmation used throughout a session.
//  A system .sheet on recent iOS may float above the screen edges;
//  this purpose-built overlay intentionally connects to those edges.
//  Its panel height is entirely content-driven (no arbitrary detents).
//

import SwiftUI
import UIKit

struct SessionExitButton: View {
    let action: () -> Void
    var disabled: Bool = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.ink.opacity(0.56))
                .frame(width: 30, height: 30)
                .background(AppTheme.paper.opacity(0.72), in: Circle())
                .overlay {
                    Circle().stroke(AppTheme.ink.opacity(0.06), lineWidth: 1)
                }
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel("Leave session")
        .accessibilityHint("Choose whether to leave or keep practicing")
    }
}

/// Rounds the two TOP corners only; the bottom edge meets the screen.
private struct TopRoundedPanel: Shape {
    var cornerRadius: CGFloat = 30

    func path(in rect: CGRect) -> Path {
        let r = min(cornerRadius, rect.width / 2, rect.height)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + r, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + r),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// A swipe down or a tap outside the panel simply resumes practice.
/// Only the explicit Leave Session button exits the exercise.
struct SessionExitConfirmationOverlay: View {
    let title: String
    let message: String
    let onKeepPracticing: () -> Void
    let onLeave: () -> Void

    @State private var dragOffset: CGFloat = 0

    /// Read from the actual app window, not the sized sheet content.
    /// The inset is used for readable/actionable content above Home Indicator;
    /// the panel background still extends ALL the way to the bottom edge.
    private var bottomWindowInset: CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        return scene?.windows.first(where: { $0.isKeyWindow })?.safeAreaInsets.bottom ?? 0
    }

    var body: some View {
        GeometryReader { viewport in
            ZStack(alignment: .bottom) {
                AppTheme.ink.opacity(0.16)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onKeepPracticing)

                VStack(spacing: 0) {
                    Capsule()
                        .fill(AppTheme.ink.opacity(0.18))
                        .frame(width: 36, height: 5)
                        .padding(.top, 10)
                        .padding(.bottom, 14)

                    Image(systemName: "heart")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(AppTheme.ink.opacity(0.74))
                        .frame(width: 42, height: 42)
                        .background(
                            LinearGradient(
                                colors: [AppTheme.mint.opacity(0.78), AppTheme.aqua.opacity(0.68)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                        )
                        .padding(.bottom, 12)

                    Text(title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 7)

                    Text(message)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.ink.opacity(0.62))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 20)

                    Button(action: onKeepPracticing) {
                        Text("Keep Practicing")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                LinearGradient(
                                    colors: [AppTheme.mint, AppTheme.aqua],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Close and resume the current exercise")

                    Button(action: onLeave) {
                        Text("Leave Session")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(AppTheme.ink.opacity(0.65))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, max(16, bottomWindowInset + 6))
                .frame(width: viewport.size.width)
                .fixedSize(horizontal: false, vertical: true)
                .background {
                    TopRoundedPanel(cornerRadius: 30)
                        .fill(AppTheme.paper)
                        .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: -3)
                }
                .offset(y: max(0, dragOffset))
                .simultaneousGesture(
                    DragGesture(minimumDistance: 15)
                        .onChanged { gesture in
                            dragOffset = max(0, gesture.translation.height)
                        }
                        .onEnded { gesture in
                            if gesture.translation.height > 85 {
                                onKeepPracticing()
                            } else {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.90)) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
                .accessibilityElement(children: .contain)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            .frame(width: viewport.size.width, height: viewport.size.height, alignment: .bottom)
        }
        // Geometry is constrained to the iPhone viewport rather than any
        // oversized decorative Velora character in the underlying view.
        .ignoresSafeArea(.container, edges: [.horizontal, .bottom])
        .preferredColorScheme(.light)
    }
}

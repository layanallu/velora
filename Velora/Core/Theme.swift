//
//  Theme.swift
//  Velora
//
//  Created by LAYAN  on 03/09/1447 AH.
//
import SwiftUI

enum AppTheme {
    // Your palette
    static let ink = Color(hex: "#000000")
    static let mint = Color(hex: "#BBECCA")
    static let aqua = Color(hex: "#B7E6DC")
    static let paper = Color(hex: "#FFFFFF")

    // Light mode background
    static let background = Color(hex: "#F6FFFC")
    static let card = Color.white.opacity(0.94)
    static let shadow = Color.black.opacity(0.08)

    // Typography (rounded, friendly)
    static let titleFont: Font = .system(size: 28, weight: .bold, design: .rounded)
    static let subtitleFont: Font = .system(size: 16, weight: .medium, design: .rounded)
    static let bodyFont: Font = .system(size: 15, weight: .regular, design: .rounded)
    static let buttonFont: Font = .system(size: 16, weight: .semibold, design: .rounded)
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, (int >> 16) & 0xff, (int >> 8) & 0xff, int & 0xff)
        case 8: (a, r, g, b) = ((int >> 24) & 0xff, (int >> 16) & 0xff, (int >> 8) & 0xff, int & 0xff)
        default:(a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r)/255,
                  green: Double(g)/255,
                  blue: Double(b)/255,
                  opacity: Double(a)/255)
    }
}

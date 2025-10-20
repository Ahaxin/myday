import SwiftUI

enum AppTheme {
    static let accent = Color("AccentColor", bundle: .main)

    static let bubblegum = Color(red: 1.0, green: 0.51, blue: 0.73)
    static let ocean = Color(red: 0.23, green: 0.65, blue: 0.96)
    static let sunny = Color(red: 1.0, green: 0.85, blue: 0.27)
    static let mint = Color(red: 0.27, green: 0.83, blue: 0.66)
    static let grape = Color(red: 0.56, green: 0.41, blue: 0.99)

    static var playfulGradient: LinearGradient {
        LinearGradient(colors: [bubblegum, sunny, mint, ocean, grape], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var ringGradient: AngularGradient {
        AngularGradient(gradient: Gradient(colors: [bubblegum, sunny, mint, ocean, grape, bubblegum]), center: .center)
    }
}


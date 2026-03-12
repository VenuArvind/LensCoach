//
//  LensCoachNativeApp.swift
//  LensCoachNative
//
//  Created by Venu Arvind Arangarajan on 3/4/26.
//

import SwiftUI
import LensCoachApp

@main
struct LensCoachNativeApp: App {
    init() {
        DiagnosticsManager.shared.startLogging()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

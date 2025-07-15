//
//  iOSSocketApp.swift
//  iOSSocket
//
//  Created by Moroti Oyeyemi on 7/14/25.
//

import SwiftUI

@main
struct iOSSocketApp: App {
    var body: some Scene {
        WindowGroup {
            if #available(iOS 16.0, *) {
                ContentView()
            } else {
                Text("iOS 16.0 or later required")
                    .padding()
            }
        }
    }
}

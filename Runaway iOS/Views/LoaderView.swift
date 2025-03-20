//
//  LoaderView.swift
//  RunawayUI
//
//  Created by Jack Rudelic on 7/22/24.
//

import Foundation
import SwiftUI

public struct LoaderView: View {
    public var body: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(2)
            Text("Loading...")
                .font(.title)
                .padding(.top, 20)
        }
    }
}

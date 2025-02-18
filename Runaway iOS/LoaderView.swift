//
//  LoaderView.swift
//  RunawayUI
//
//  Created by Jack Rudelic on 7/22/24.
//

import Foundation
import SwiftUI

struct LoaderView: View {
    
 @State var isAnimating = false
    
    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(Color.blue, lineWidth: 4)
                .frame(width: 80, height: 80)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .foregroundColor(Color.blue)
                .onAppear() {
                    withAnimation(Animation
                                    .linear(duration: 1)
                                    .repeatForever(autoreverses: false)) {
                        self.isAnimating = true
                    }
                }
        }
    }
}

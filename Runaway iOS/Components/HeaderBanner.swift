//
//  Header.swift
//  RunawayUI
//
//  Created by Jack Rudelic on 7/22/24.
//

import SwiftUI

struct HeaderBanner: View {
    
    var backgroundImage: String?
    
    var body: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .foregroundColor(Color(red: 13 / 255, green: 0 / 255, blue: 255 / 255))
                .edgesIgnoringSafeArea(.top)
                .frame(height: 100)
            AsyncImage(url: URL(string: backgroundImage!)) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                ProgressView()
            }
            .frame(width: 200, height: 200)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white, lineWidth: 4))
            .shadow(radius: 10)
        }
    }
}

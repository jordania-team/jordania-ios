//
//  ContentView.swift
//  AuthPlayground
//
//  Created by Gabriel Ferrari on 31/05/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 8) {
                    Image(systemName: "person.badge.key.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.indigo)

                    Text("Auth Playground")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("POC de autenticação iOS\nApple · Google · Persistência local")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("")
        }
    }
}

#Preview {
    ContentView()
}

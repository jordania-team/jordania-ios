//
//  MainTabView.swift
//  JordaniaTeam
//
//  Created by Gabriel Ferrari on 29/06/26.
//

import SwiftUI

struct MainTabView: View {

    let container: AppContainer

    var body: some View {
        TabView {
            Tab("Feed", systemImage: "rectangle.stack.fill") {
                FeedView()
            }

            Tab("Map", systemImage: "location.fill") {
                MapView()
            }

            Tab("Profile", systemImage: "person.fill") {
                ProfileView()
            }

            Tab("Search", systemImage: "magnifyingglass", role: .search) {
                SearchView()
            }
        }
    }
}

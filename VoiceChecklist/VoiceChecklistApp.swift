//
//  VoiceChecklistApp.swift
//  VoiceChecklist
//
//  Created by Ben Hirashima on 1/27/23.
//

import SwiftUI

@main
struct VoiceChecklistApp: App {
    @StateObject private var store = CListStore()
    
    var body: some Scene {
        WindowGroup {
            CListsView(checklists: $store.clists) {
                // the contents of the saveClists closure that CListsView requires for init
                Task { // executes asynchronously
                    do {
                        try await CListStore.save(clists: store.clists)
                    } catch {
                        fatalError("Failed to save checklists")
                    }
                }
            }
            .task { // executed asynchronously when CListsView appears. automatically canceled if view disappears.
                if store.clists.count == 0 {
                    do {
                        store.clists = try await CListStore.load()
                        if (store.clists.isEmpty) {
                            store.clists = CList.sampleData
                        }
                    } catch {
                        fatalError("Failed to load checklists")
                    }
                }
            }
        }
    }
}

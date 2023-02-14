//
//  CListsView.swift
//  VoiceChecklist
//
//  Created by Ben Hirashima on 1/27/23.
//

import SwiftUI

struct CListsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Binding var checklists: [CList]
    @State private var newCList = CList()
    @State private var isShowingAddClistView = false
    
    @State private var isShowingUndo = false
    @State private var fadeOutUndoDuration: Double = 1
    @State private var deletedClist: [Int: CList] = [:]
    
    @Environment(\.accessibilityDifferentiateWithoutColor) var differentiateWithoutColor
    
    let saveClists: ()->Void
    
    private func deleteChecklist(_ indices: IndexSet) {
        // clear any previous deletion
        deletedClist.removeAll()
        // even though onDelete gives us an array of indices, there should be only one in it
        for index in indices {
            // updateValue inserts if key doesn't exist
            deletedClist.updateValue(checklists[index], forKey: index)
        }
        checklists.remove(atOffsets: indices)
    }
    
    private func undoDeleteChecklist() {
        // insert deleted checklist at it's original position
        checklists.insert(contentsOf: deletedClist.values, at: deletedClist.keys.first ?? checklists.count)
        deletedClist.removeAll()
    }
    
    private func showUndoButton() {
        isShowingUndo = true
        // hide undo button after a delay
        fadeOutUndoDuration = 1 // reset value in case it was zeroed out by hideUndoButton()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            isShowingUndo = false
        }
    }
    
    private func hideUndoButton() {
        fadeOutUndoDuration = 0 // ensures animation is not running if we come back to this screen quickly
        isShowingUndo = false
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                List {
                    ForEach($checklists) { $clist in
                        NavigationLink(destination: CListPlay(clist: $clist, saveClists: saveClists, voiceMan: VoiceManager(clist: $clist), addCList: {_ in })) {
                            HStack {
                                let status = clist.getCheckedStatus()
                                Image(systemName: clist.getCheckIconName(status: status, differentiateWithoutColor: differentiateWithoutColor))
                                    .foregroundColor(clist.getCheckIconColor(status: status))
                                Text(clist.title)
                            }
                        }
                        .listRowBackground(Color("ListRowBackgroundColor"))
                    }
                    .onDelete { indices in
                        deleteChecklist(indices)
                        showUndoButton()
                    }
                    .onMove { source, dest in
                        checklists.move(fromOffsets: source, toOffset: dest)
                    }
                }
                .offset(x: 0, y: 40)
                Color($checklists.isEmpty ? UIColor(Color("ListBackgroundColor")) : .clear).ignoresSafeArea() // workaround for inability to set list background color when it's empty.
                HStack{
                    Text("Checklists")
                        .font(.title)
                        .fontWeight(.light)
                        .padding([.leading], 20.0)
                        .padding(.vertical, 18.0)
                    Spacer()
                }
                .background(Color("ListBackgroundColor"))
            }
            .toolbar {
                Button(action: {
                    hideUndoButton()
                    isShowingAddClistView = true
                    newCList = CList()
                }) {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New Checklist")
                .navigationDestination(isPresented: $isShowingAddClistView) {
                    CListPlay(clist: $newCList, saveClists: saveClists, voiceMan: VoiceManager(clist: $newCList), addCList: {
                        if let clist = $0 {
                            checklists.append(clist)
                        }
                    })
                }
            }
            .onChange(of: scenePhase) { phase in
                if phase == .inactive { saveClists() } // saves order
            }
            .onDisappear() {
                hideUndoButton()
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    hideUndoButton()
                    undoDeleteChecklist()
                } label: {
                    Text("Undo Delete")
                    Image(systemName: "arrow.uturn.backward")
                }
                .padding(.bottom)
                .buttonStyle(.bordered)
                .controlSize(.large)
                .opacity(isShowingUndo ? 1 : 0)
                .animation(isShowingUndo ? .easeIn : .easeOut(duration: fadeOutUndoDuration), value: isShowingUndo)
            }
            .scrollContentBackground(.hidden)
            .background(Color("ListBackgroundColor"))
            .toolbarBackground(Color("ThemeColor"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct CListView_Previews: PreviewProvider {
    static var previews: some View {
        BindingProvider(CList.sampleData) { binding in
            NavigationStack {
                CListsView(checklists: binding, saveClists: {})
            }
        }
    }
}

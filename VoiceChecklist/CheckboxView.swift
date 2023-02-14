//
//  CheckboxView.swift
//  VoiceChecklist
//
//  Created by Ben Hirashima on 1/28/23.
//

import SwiftUI

struct CheckboxView: View {
    @Binding var item: CList.CListItem

    var body: some View {
        Button(action: { item.isChecked.toggle() }) {
            HStack {
                Image(systemName: item.isChecked ? "checkmark.circle" : "circle")
                    .foregroundColor(item.isChecked ? .gray : .accentColor) 
                Text(item.title)
                    .foregroundColor(item.isChecked ? .gray : .primary) 
            }
            .background(.clear)
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)) // helps align check circles with header
    }
}

struct CheckboxView_Previews: PreviewProvider {
    static var previews: some View {
        CheckboxView(item: .constant(CList.CListItem(title: "Checkbox", isChecked: true)))
    }
}

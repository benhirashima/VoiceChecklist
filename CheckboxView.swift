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
                Text(item.title)
            }
            .foregroundColor(item.isChecked ? .gray : .blue)
        }
    }
}

struct CheckboxView_Previews: PreviewProvider {
    static var previews: some View {
        CheckboxView(item: .constant(CList.CListItem(title: "Checkbox", isChecked: true)))
    }
}

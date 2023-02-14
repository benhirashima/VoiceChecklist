//
//  CList.swift
//  VoiceChecklist
//
//  Created by Ben Hirashima on 1/27/23.
//

import Foundation
import SwiftUI

struct CList: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var items: [CListItem]
    
    init(id: UUID = UUID(), title: String = "", items: [CListItem] = []) {
        self.id = id
        self.title = title
        self.items = items
    }
}

extension CList {
    struct CListItem: Identifiable, Codable, Hashable {
        let id: UUID
        var title: String
        var isChecked: Bool
        
        init(id: UUID = UUID(), title: String, isChecked: Bool = false) {
            self.id = id
            self.title = title
            self.isChecked = isChecked
        }
    }
    
    enum Status {
        case allChecked
        case partialChecked
        case noneChecked
    }
    
    func getCheckedStatus() -> Status {
        if items.isEmpty { return Status.noneChecked }
        var partial = false
        var allChecked = true
        for item in items {
            if item.isChecked  {
                partial = true
            } else {
                allChecked = false
            }
        }
        if allChecked { return Status.allChecked }
        else if partial { return Status.partialChecked }
        else { return Status.noneChecked }
    }
    
    func isAllChecked() -> Bool {
        for item in items {
            if !item.isChecked  { return false }
        }
        return !items.isEmpty 
    }
    
    func isSomeChecked() -> Bool {
        for item in items {
            if item.isChecked  { return true }
        }
        return false
    }
    
    func getCheckIconName(status: Status, differentiateWithoutColor: Bool) -> String {
        switch status {
        case .allChecked: return differentiateWithoutColor ? "checkmark.circle.fill" : "checkmark.circle" // use filled checkmark circle for colorblindness
        case .partialChecked: return "checkmark.circle"
        default: return "circle"
        }
    }
    
    func getCheckIconColor(status: Status) -> Color {
        switch status {
        case .allChecked: return .accentColor
        case .partialChecked: return .gray
        default: return .primary
        }
    }
    
    static func copyValues(from: CList, to: inout CList) -> Void {
        to.title = from.title
        to.items = from.items
    }
    
    static let sampleData: [CList] =
    [
        CList(title: "Example checklist", items: [CListItem(title: "Swipe left to delete"), CListItem(title: "Tap and hold to move"), CListItem(title: "Tap the microphone to use voice")])
    ]
}

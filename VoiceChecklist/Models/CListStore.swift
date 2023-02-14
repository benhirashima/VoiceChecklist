//
//  CListStore.swift
//  VoiceChecklist
//
//  Created by Ben Hirashima on 2/1/23.
//

import Foundation
import SwiftUI

class CListStore: ObservableObject {
    @Published var clists: [CList] = []
    
    private static func fileURL() throws -> URL {
        try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("clists.data")
    }
    
    static func load(completion: @escaping (Result<[CList], Error>)->Void) {
        DispatchQueue.global(qos: .background).async {
            do {
                let fileURL = try fileURL()
                guard let file = try? FileHandle(forReadingFrom: fileURL) else {
                    DispatchQueue.main.async {
                        completion(.success([]))
                    }
                    return
                }
                let clists = try JSONDecoder().decode([CList].self, from: file.availableData)
                DispatchQueue.main.async {
                    completion(.success(clists))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    static func load() async throws -> [CList] {
        try await withCheckedThrowingContinuation { cont in
            load { result in
                switch result {
                case .success(let clists):
                    cont.resume(returning: clists)
                case .failure(let err):
                    cont.resume(throwing: err)
                }
            }
        }
    }
    
    static func save(clists: [CList], completion: @escaping (Result<Int, Error>)->Void) {
        DispatchQueue.global(qos: .background).async {
            do {
                let file = try fileURL()
                let data = try JSONEncoder().encode(clists)
                try data.write(to: file)
                DispatchQueue.main.async {
                    completion(.success(clists.count))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    @discardableResult
    static func save(clists: [CList]) async throws -> Int {
        try await withCheckedThrowingContinuation { cont in
            save(clists: clists) { result in
                switch result {
                case .success(let isSaved):
                    cont.resume(returning: isSaved)
                case .failure(let err):
                    cont.resume(throwing: err)
                }
            }
        }
    }
}


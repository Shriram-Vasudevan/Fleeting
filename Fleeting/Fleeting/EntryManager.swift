//
//  EntryManager.swift
//  Fleeting
//
//  Created by Shriram Vasudevan on 4/14/25.
//

//
//  JournalStorageManager.swift
//  Fleeting
//
//  Created by Shriram Vasudevan on 4/14/25.
//

import Foundation
import CoreData
import SwiftUI

// Simple JournalEntry struct with just the required fields
struct JournalEntry: Identifiable {
    var id: String
    var content: String
    var createdAt: Date
    var wordCount: Int
}

class JournalStorageManager: ObservableObject {
    static let shared = JournalStorageManager()

    @Published var entries: [JournalEntry] = []
    @Published var currentEntry: String = ""

    private lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "FleetingData")
        
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                print("Persistent store failed to load: \(error.localizedDescription)")
            }
        }
        
        return container
    }()
    
    private var context: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    private init() {
        loadEntries()
    }

    // MARK: - Public Methods

    func saveCurrentEntry() {
        // Only save if there's content
        let trimmedContent = currentEntry.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }

        // Check if we already have an entry for today
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let existingTodayEntry = entries.first(where: {
            calendar.isDate($0.createdAt, inSameDayAs: today)
        }) {
            // Update today's entry
            updateEntry(id: existingTodayEntry.id, content: trimmedContent)
        } else {
            // Create a new entry
            let wordCount = trimmedContent.split(separator: " ").count
            let entry = JournalEntry(
                id: UUID().uuidString,
                content: trimmedContent,
                createdAt: Date(),
                wordCount: wordCount
            )
            saveEntry(entry)
        }
        
        // Clear the current entry
        currentEntry = ""
        
        // Reload entries
        loadEntries()
    }

    func getWordCountsByDate() -> [(date: Date, count: Int)] {
        let calendar = Calendar.current
        var result: [Date: Int] = [:]
        
        for entry in entries {
            // Normalize to start of day
            let startOfDay = calendar.startOfDay(for: entry.createdAt)
            result[startOfDay, default: 0] += entry.wordCount
        }
        
        return result.map { (date: $0.key, count: $0.value) }.sorted { $0.date < $1.date }
    }

    // MARK: - Private Methods

    private func saveEntry(_ entry: JournalEntry) {
        guard let entity = NSEntityDescription.entity(forEntityName: "JournalEntry", in: context) else {
            print("Failed to get JournalEntry entity")
            return
        }
        
        let entryEntity = NSManagedObject(entity: entity, insertInto: context)
        
        entryEntity.setValue(entry.id, forKey: "id")
        entryEntity.setValue(entry.content, forKey: "content")
        entryEntity.setValue(entry.createdAt, forKey: "createdAt")
        entryEntity.setValue(entry.wordCount, forKey: "wordCount")
        
        do {
            try context.save()
            print("Journal entry saved successfully")
        } catch {
            print("Failed to save journal entry: \(error.localizedDescription)")
        }
    }
    
    private func updateEntry(id: String, content: String) {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "JournalEntry")
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        
        do {
            let results = try context.fetch(fetchRequest)
            if let entryToUpdate = results.first {
                // Calculate new word count
                let wordCount = content.split(separator: " ").count
                
                // Update fields
                entryToUpdate.setValue(content, forKey: "content")
                entryToUpdate.setValue(wordCount, forKey: "wordCount")
                
                try context.save()
                print("Journal entry updated successfully")
            }
        } catch {
            print("Failed to update journal entry: \(error.localizedDescription)")
        }
    }

    func loadEntries() {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "JournalEntry")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        do {
            let results = try context.fetch(fetchRequest)
            entries = results.compactMap { entity -> JournalEntry? in
                guard let id = entity.value(forKey: "id") as? String,
                      let content = entity.value(forKey: "content") as? String,
                      let createdAt = entity.value(forKey: "createdAt") as? Date,
                      let wordCount = entity.value(forKey: "wordCount") as? Int else {
                    return nil
                }
                
                return JournalEntry(id: id, content: content, createdAt: createdAt, wordCount: wordCount)
            }
            
            // If there's an entry for today, load it into currentEntry
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            
            if let todayEntry = entries.first(where: { calendar.isDate($0.createdAt, inSameDayAs: today) }),
               currentEntry.isEmpty {
                currentEntry = todayEntry.content
            }
            
        } catch {
            print("Failed to fetch journal entries: \(error.localizedDescription)")
        }
    }
}

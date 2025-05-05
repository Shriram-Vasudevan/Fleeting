//
//  Persistence.swift
//  Fleeting
//
//  Created by Shriram Vasudevan on 4/14/25.
//

import CoreData

import CoreData

//struct PersistenceController {
//    static let shared = PersistenceController()
//    
//    let container: NSPersistentContainer
//    
//    init(inMemory: Bool = false) {
//        container = NSPersistentContainer(name: "Fleeting")
//        
//        if inMemory {
//            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
//        }
//        
//        container.loadPersistentStores { (storeDescription, error) in
//            if let error = error as NSError? {
//                fatalError("Unresolved error \(error), \(error.userInfo)")
//            }
//        }
//        
//        container.viewContext.automaticallyMergesChangesFromParent = true
//        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
//    }
//    
//    // Preview for SwiftUI previews
//    static var preview: PersistenceController = {
//        let result = PersistenceController(inMemory: true)
//        let viewContext = result.container.viewContext
//        
//        // Create sample data
//        for i in 0..<5 {
//            let newEntry = Entry(context: viewContext)
//            newEntry.id = UUID()
//            newEntry.content = "This is sample entry \(i)"
//            newEntry.createdAt = Date().addingTimeInterval(-Double(i * 86400))
//            newEntry.wordCount = Int16(newEntry.content?.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count ?? 0)
//        }
//        
//        do {
//            try viewContext.save()
//        } catch {
//            let nsError = error as NSError
//            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
//        }
//        
//        return result
//    }()
//}

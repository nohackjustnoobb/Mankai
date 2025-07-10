//
//  DbService.swift
//  mankai
//
//  Created by Travis XU on 26/6/2025.
//

import CoreData
import Foundation

class DbService {
    static let shared = DbService()

    private init() {}

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Model")

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Core Data error: \(error), \(error.userInfo)")
            }
        }

        return container
    }()

    private var context: NSManagedObjectContext {
        let viewContext = persistentContainer.viewContext

        viewContext.automaticallyMergesChangesFromParent = true
        viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        return viewContext
    }

    func saveContext() throws {
        let context = persistentContainer.viewContext

        if context.hasChanges {
            try context.save()
        }
    }

    func getContext() -> NSManagedObjectContext {
        return context
    }
}

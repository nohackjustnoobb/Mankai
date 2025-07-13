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

    lazy var context: NSManagedObjectContext = {
        let viewContext = persistentContainer.viewContext

        viewContext.automaticallyMergesChangesFromParent = true
        viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        return viewContext
    }()
}

import CoreData

class CoreDataStack {
    let container: NSPersistentContainer
    let mainContext: NSManagedObjectContext
    let backgroundContext: NSManagedObjectContext
    
    init() {
        container = NSPersistentContainer(name: "CoreDataApp")
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        mainContext = container.viewContext
        backgroundContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        backgroundContext.parent = mainContext
    }
    
    func saveContext() {
        guard mainContext.hasChanges else { return }
        do {
            try mainContext.save()
        } catch {
            let nserror = error as NSError
            fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
        }
    }
    
    func saveBackgroundContext() {
        guard backgroundContext.hasChanges else { return }
        do {
            try backgroundContext.save()
            mainContext.perform {
                self.mainContext.mergeChanges(fromContextDidSave: self.backgroundContext)
            }
        } catch {
            let nserror = error as NSError
            fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
        }
    }
}

import CoreData

@objc(Entity)
public class Entity: NSManagedObject {
    @NSManaged public var name: String?
}

class DataManager {
    let coreDataStack: CoreDataStack
    
    init(coreDataStack: CoreDataStack) {
        self.coreDataStack = coreDataStack
    }
    
    func createEntity(name: String, completion: @escaping (Entity?) -> Void) {
        coreDataStack.backgroundContext.perform {
            let entity = Entity(context: self.coreDataStack.backgroundContext)
            entity.name = name
            self.coreDataStack.saveBackgroundContext()
            completion(entity)
        }
    }
    
    func readEntities(completion: @escaping ([Entity]) -> Void) {
        coreDataStack.backgroundContext.perform {
            let fetchRequest: NSFetchRequest<Entity> = Entity.fetchRequest()
            do {
                let entities = try self.coreDataStack.backgroundContext.fetch(fetchRequest)
                self.coreDataStack.mainContext.perform {
                    completion(entities)
                }
            } catch {
                self.coreDataStack.mainContext.perform {
                    completion([])
                }
            }
        }
    }
    
    func updateEntity(entity: Entity, newName: String, completion: @escaping (Bool) -> Void) {
        coreDataStack.backgroundContext.perform {
            entity.name = newName
            self.coreDataStack.saveBackgroundContext()
            completion(true)
        }
    }
    
    func deleteEntity(entity: Entity, completion: @escaping (Bool) -> Void) {
        coreDataStack.backgroundContext.perform {
            self.coreDataStack.backgroundContext.delete(entity)
            self.coreDataStack.saveBackgroundContext()
            completion(true)
        }
    }
}


let coreDataStack = CoreDataStack()
let dataManager = DataManager(coreDataStack: coreDataStack)

// Create a new entity
dataManager.createEntity(name: "New Entity") { entity in
    if let entity = entity {
        print("Entity created: \(entity.name ?? "Unnamed")")
    } else {
        print("Failed to create entity")
    }
}

// Read entities
dataManager.readEntities { entities in
    print("Entities: \(entities)")
}

// Update an entity
if let entityToUpdate = Entity(context: coreDataStack.mainContext) {
    dataManager.updateEntity(entity: entityToUpdate, newName: "Updated Entity") { success in
        print(success ? "Entity updated" : "Failed to update entity")
    }
}

// Delete an entity
if let entityToDelete = Entity(context: coreDataStack.mainContext) {
    dataManager.deleteEntity(entity: entityToDelete) { success in
        print(success ? "Entity deleted" : "Failed to delete entity")
    }
}

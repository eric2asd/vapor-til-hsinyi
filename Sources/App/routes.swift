import Vapor
import Fluent

/// Register your application's routes here.
public func routes(_ router: Router) throws {
  // Basic "It works" example
  router.get { req in
    return "It works!"
  }
  
  // Basic "Hello, world!" example
  router.get("hello") { req in
    return "Hello, world!"
  }
  
  let acronymsController = AcronymsController()
  try router.register(collection: acronymsController)
  
  let usersController = UsersController()
  try router.register(collection: usersController)
  
  let categories = CategoriesController()
  try router.register(collection: categories)
  
  let websiteController = WebsiteController()
  try router.register(collection: websiteController)
  
  let imperialController = ImperialController()
  try router.register(collection: imperialController)
}

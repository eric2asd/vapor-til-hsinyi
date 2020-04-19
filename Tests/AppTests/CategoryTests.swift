@testable import App
import Vapor
import XCTest
import FluentPostgreSQL

final class CategoryTests: XCTestCase {
  
  let categoriesName = "Teenager"
  let categoriesURI = "/api/categories/"
  var app: Application!
  var conn: PostgreSQLConnection!
  
  override func setUp() {
    try! Application.reset()
    app = try! Application.testable()
    conn = try! app.newConnection(to: .psql).wait()
  }
  
  override func tearDown() {
    conn.close()
    try? app.syncShutdownGracefully()
  }
  
  func testCategoriesCanBeRetrievedFromAPI() throws {
    let category = try Category.create(name: categoriesName, on: conn)
    _ = try Category.create(on: conn)
    let categories = try app.getResponse(to: categoriesURI, decodeTo: [App.Category].self)
    XCTAssertEqual(categories.count, 2)
    XCTAssertEqual(categories[0].name, categoriesName)
    XCTAssertEqual(categories[0].id, category.id)
  }
  
  func testCategoryCanBeSavedWithAPI() throws {
    let category = Category(name: categoriesName)
    let receivedCategory = try app.getResponse(to: categoriesURI, method: .POST, headers: ["Content-Type": "application/json"], data: category, decodeTo: Category.self, loggedInRequest: true)
    XCTAssertEqual(receivedCategory.name, categoriesName)
    XCTAssertNotNil(receivedCategory.id)
    
    let categories = try app.getResponse(to: categoriesURI, decodeTo: [App.Category].self)
    XCTAssertEqual(categories.count, 1)
    XCTAssertEqual(categories[0].name, categoriesName)
    XCTAssertEqual(categories[0].id, receivedCategory.id)
  }
  
  func testGettingASingleCategoryFromTheAPI() throws {
    let category = try Category.create(name: categoriesName, on: conn)
    let receivedCategory = try app.getResponse(to: categoriesURI + "\(category.id!)", decodeTo: App.Category.self)
    XCTAssertEqual(receivedCategory.name, categoriesName)
    XCTAssertEqual(receivedCategory.id, category.id)
  }
  
  func testGettingACategoriesAcronymsFromTheAPI() throws {
    let acronymsShort = "OMG"
    let acronymsLong = "Oh My God"
    let acronym1 = try Acronym.create(short: acronymsShort, long: acronymsLong, on: conn)
    let acronym2 = try Acronym.create(on: conn)
    let category = try Category.create(on: conn)
    _ = try app.sendRequest(to: "/api/acronyms/\(acronym1.id!)/categories/\(category.id!)", method: .POST, loggedInRequest: true)
    _ = try app.sendRequest(to: "/api/acronyms/\(acronym2.id!)/categories/\(category.id!)", method: .POST, loggedInRequest: true)
    
    let receivedAcronyms = try app.getResponse(to: categoriesURI + "\(category.id!)/acronyms", decodeTo: [Acronym].self)
    XCTAssertEqual(receivedAcronyms.count, 2)
    XCTAssertEqual(receivedAcronyms[0].id, acronym1.id)
    XCTAssertEqual(receivedAcronyms[0].short, acronymsShort)
    XCTAssertEqual(receivedAcronyms[0].long, acronymsLong)
  }
  
  static let allTests = [
    ("testCategoriesCanBeRetrievedFromAPI", testCategoriesCanBeRetrievedFromAPI),
    ("testCategoryCanBeSavedWithAPI", testCategoryCanBeSavedWithAPI),
    ("testGettingASingleCategoryFromTheAPI", testGettingASingleCategoryFromTheAPI),
    ("testGettingACategoriesAcronymsFromTheAPI", testGettingACategoriesAcronymsFromTheAPI),
  ]
}

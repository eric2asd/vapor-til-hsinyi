@testable import App
import Vapor
import XCTest
import FluentPostgreSQL

class AcronymsTests: XCTestCase {
  
  let acronymsShort = "OMG"
  let acronymsLong = "Oh My God"
  let acronymsURI = "/api/acronyms/"
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
  
  func testAcronymsCanBeRetrievedFromAPI() throws {
    let acronym = try Acronym.create(short: acronymsShort, long: acronymsLong, on: conn)
    _ = try Acronym.create(on: conn)
    let acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
    
    XCTAssertEqual(acronyms.count, 2)
    XCTAssertEqual(acronyms[0].id, acronym.id)
    XCTAssertEqual(acronyms[0].short, acronym.short)
    XCTAssertEqual(acronyms[0].long, acronym.long)
  }
  
  func testAcronymCanBeSavedWithAPI() throws {
    let user = try User.create(on: conn)
    let acronym = Acronym(short: acronymsShort, long: acronymsLong, userID: user.id!)
    let receivedAcronym = try app.getResponse(to: acronymsURI, method: .POST, headers: ["Content-Type": "application/json"], data: acronym, decodeTo: Acronym.self, loggedInUser: user)
    XCTAssertEqual(receivedAcronym.short, acronymsShort)
    XCTAssertEqual(receivedAcronym.long, acronymsLong)
    XCTAssertEqual(receivedAcronym.userID, user.id)
    XCTAssertNotNil(receivedAcronym.id)
    
    let acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
    XCTAssertEqual(acronyms.count, 1)
    XCTAssertEqual(acronyms[0].id, receivedAcronym.id)
    XCTAssertEqual(acronyms[0].short, acronym.short)
    XCTAssertEqual(acronyms[0].long, acronym.long)
    XCTAssertEqual(acronyms[0].userID, user.id)
  }
  
  func testGettingASingleAcronymFromTheAPI() throws {
    let acronym = try Acronym.create(short: acronymsShort, long: acronymsLong, on: conn)
    let receivedAcronym = try app.getResponse(to: acronymsURI + "\(acronym.id!)", decodeTo: Acronym.self)
    
    XCTAssertEqual(receivedAcronym.short, acronymsShort)
    XCTAssertEqual(receivedAcronym.long, acronymsLong)
    XCTAssertEqual(receivedAcronym.id, acronym.id)
  }
  
  func testUpdatingAnAcronym() throws {
    let acronym = try Acronym.create(short: acronymsShort, long: acronymsLong, on: conn)
    let newUser = try User.create(on: conn)
    let newLong = "Oh My Gosh"
    let updatedAcronym = Acronym(short: acronymsShort, long: newLong, userID: newUser.id!)
    try app.sendRequest(to: acronymsURI + "\(acronym.id!)", method: .PUT, headers: ["Content-Type": "application/json"], data: updatedAcronym, loggedInUser: newUser)
    let returnedAcronym = try app.getResponse(to: acronymsURI + "\(acronym.id!)", decodeTo: Acronym.self)
    XCTAssertEqual(returnedAcronym.short, acronymsShort)
    XCTAssertEqual(returnedAcronym.long, newLong)
    XCTAssertEqual(returnedAcronym.userID, newUser.id)
  }
  
  func testDeletingAnAcronym() throws {
    let acronym = try Acronym.create(on: conn)
    var acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
    
    XCTAssertEqual(acronyms.count, 1)
    
    _ = try app.sendRequest(to: acronymsURI + "\(acronym.id!)", method: .DELETE, loggedInRequest: true)
    acronyms = try app.getResponse(to: acronymsURI, decodeTo: [Acronym].self)
    
    XCTAssertEqual(acronyms.count, 0)

  }
  
  func testSearchAcronymShort() throws {
    let acronym = try Acronym.create(short: acronymsShort, long: acronymsLong, on: conn)
    let acronyms = try app.getResponse(to: acronymsURI + "search?term=OMG", decodeTo: [Acronym].self)
    XCTAssertEqual(acronyms.count, 1)
    XCTAssertEqual(acronyms[0].id, acronym.id)
    XCTAssertEqual(acronyms[0].short, acronym.short)
    XCTAssertEqual(acronyms[0].long, acronym.long)

  }
  
  func testSearchAcronymLong() throws {
    let acronym = try Acronym.create(short: acronymsShort, long: acronymsLong, on: conn)
    let acronyms = try app.getResponse(to: acronymsURI + "search?term=Oh+My+God", decodeTo: [Acronym].self)
    XCTAssertEqual(acronyms.count, 1)
    XCTAssertEqual(acronyms[0].id, acronym.id)
    XCTAssertEqual(acronyms[0].short, acronym.short)
    XCTAssertEqual(acronyms[0].long, acronym.long)

  }
  
  func testGetFirstAcronym() throws {
    let acronym = try Acronym.create(short: acronymsShort, long: acronymsLong, on: conn)
    _ = try Acronym.create(on: conn)
    _ = try Acronym.create(on: conn)

    let firstAcronym = try app.getResponse(to: acronymsURI + "first", decodeTo: Acronym.self)
    XCTAssertEqual(firstAcronym.short, acronymsShort)
    XCTAssertEqual(firstAcronym.long, acronymsLong)
    XCTAssertEqual(firstAcronym.id, acronym.id)

  }
  
  func testSortingAcronyms() throws {
    let short2 = "LOL"
    let long2 = "Laugh Out Loud"
    let acronym1 = try Acronym.create(short: acronymsShort, long: acronymsLong, on: conn)
    let acronym2 = try Acronym.create(short: short2, long: long2, on: conn)
    
    let acronyms = try app.getResponse(to: acronymsURI + "sorted", decodeTo: [Acronym].self)
    
    XCTAssertEqual(acronyms[0].id, acronym2.id)
    XCTAssertEqual(acronyms[1].id, acronym1.id)

  }
  
  func testGettingAnAcronymsUser() throws {
    let usersName = "Eric"
    let usersUsername = "eric"
    let user = try User.create(name: usersName, username: usersUsername, on: conn)
    let acronym = try Acronym.create(short: acronymsShort, long: acronymsLong, user: user, on: conn)
    let acronymsUser = try app.getResponse(to: acronymsURI + "\(acronym.id!)/user", decodeTo: User.Public.self)
    XCTAssertEqual(acronymsUser.id, user.id)
    XCTAssertEqual(acronymsUser.name, usersName)
    XCTAssertEqual(acronymsUser.username, usersUsername)

  }
  
  func testAcronymsCategories() throws {
    let categoryName = "Funny"
    let category1 = try Category.create(on: conn)
    let category2 = try Category.create(name: categoryName, on: conn)
    let acronym = try Acronym.create(on: conn)
    _ = try app.sendRequest(to: acronymsURI + "\(acronym.id!)/categories/\(category1.id!)", method: .POST, loggedInRequest: true)
    _ = try app.sendRequest(to: acronymsURI + "\(acronym.id!)/categories/\(category2.id!)", method: .POST, loggedInRequest: true)
    let categories = try app.getResponse(to: acronymsURI + "\(acronym.id!)/categories", decodeTo: [App.Category].self)
    
    XCTAssertEqual(categories.count, 2)
    XCTAssertEqual(categories[0].id, category1.id)
    XCTAssertEqual(categories[0].name, category1.name)
    XCTAssertEqual(categories[1].id, category2.id)
    XCTAssertEqual(categories[1].name, categoryName)
    
    _ = try app.sendRequest(to: "\(acronymsURI)\(acronym.id!)/categories/\(category1.id!)", method: .DELETE, loggedInRequest: true)
    let newCategories = try app.getResponse(to: "\(acronymsURI)\(acronym.id!)/categories", decodeTo: [App.Category].self)

    XCTAssertEqual(newCategories.count, 1)

  }
  
  static let allTests = [
    ("testAcronymsCanBeRetrievedFromAPI", testAcronymsCanBeRetrievedFromAPI),
    ("testAcronymCanBeSavedWithAPI", testAcronymCanBeSavedWithAPI),
    ("testGettingASingleAcronymFromTheAPI", testGettingASingleAcronymFromTheAPI),
    ("testUpdatingAnAcronym", testUpdatingAnAcronym),
    ("testDeletingAnAcronym", testDeletingAnAcronym),
    ("testSearchAcronymShort", testSearchAcronymShort),
    ("testSearchAcronymLong", testSearchAcronymLong),
    ("testGetFirstAcronym", testGetFirstAcronym),
    ("testSortingAcronyms", testSortingAcronyms),
    ("testGettingAnAcronymsUser", testGettingAnAcronymsUser),
    ("testAcronymsCategories", testAcronymsCategories),
    ]
  
}

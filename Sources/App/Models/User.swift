import Vapor
import FluentPostgreSQL
import Authentication

final class User: Codable {
  var id: UUID?
  var name: String
  var username: String
  var password: String
  var email: String
  var profilePicture: String?
  var twitterURL: String?
  var deletedAt: Date?
  var userType: UserType
  
  init(name: String, username: String, password: String, email: String, profilePicture: String? = nil, twitterURL: String? = nil, userType: UserType = .standard) {
    self.name = name
    self.username = username
    self.password = password
    self.email = email
    self.profilePicture = profilePicture
    self.twitterURL = twitterURL
    self.userType = userType
  }
  
  final class Public: Codable {
    var id: UUID?
    var name: String
    var username: String
    init(id: UUID?, name: String, username: String) {
      self.id = id
      self.name = name
      self.username = username
    }
  }
  
  final class PublicV2: Codable {
    var id: UUID?
    var name: String
    var username: String
    var profilePicture: String?
    var twitterURL: String?

    init(id: UUID?, name: String, username: String, profilePicture: String? = nil, twitterURL: String? = nil) {
      self.id = id
      self.name = name
      self.username = username
      self.profilePicture = profilePicture
      self.twitterURL = twitterURL
    }
  }
}

extension User: PostgreSQLUUIDModel {
  typealias Database = PostgreSQLDatabase
  static var deletedAtKey: TimestampKey? = \.deletedAt
  
  func willCreate(on conn: PostgreSQLConnection)
    throws -> Future<User> {
      // 2
      return User.query(on: conn)
        .filter(\.username == self.username)
        .count()
        .map(to: User.self) { count in
          // 3
          guard count == 0 else {
            throw BasicValidationError("Username already exists")
          }
          return self
      }
  }
}
extension User: Content {}
extension User: Migration {
  static func prepare(on connection: PostgreSQLConnection) -> Future<Void> {
    return Database.create(self, on: connection) { builder in
      builder.field(for: \.id, isIdentifier: true)
      builder.field(for: \.name)
      builder.field(for: \.username)
      builder.field(for: \.password)
      builder.field(for: \.profilePicture)
      builder.field(for: \.email)
      builder.field(for: \.deletedAt)
      builder.field(for: \.userType)
      builder.unique(on: \.username)
      builder.unique(on: \.email)
    }
  }
}
extension User: Parameter {}
extension User.Public: Content {}
extension User.PublicV2: Content {}

extension User {
  var acronyms: Children<User, Acronym> {
    return children(\.userID)
  }
}

extension User {
  func convertToPublic() -> User.Public {
    return User.Public(id: id, name: name, username: username)
  }
  
  func convertToPublicV2() -> User.PublicV2 {
    return User.PublicV2(id: id, name: name, username: username, profilePicture: profilePicture, twitterURL: twitterURL)
  }
}

extension Future where T: User {
  func convertToPublic() -> Future<User.Public> {
    return self.map(to: User.Public.self) { user in
      return user.convertToPublic()
    }
  }
  
  func convertToPublicV2() -> Future<User.PublicV2> {
    return self.map(to: User.PublicV2.self) { user in
      return user.convertToPublicV2()
    }
  }

}

extension User: BasicAuthenticatable {
  static let usernameKey: UsernameKey = \User.username
  static let passwordKey: PasswordKey = \User.password
}

extension User: TokenAuthenticatable {
  typealias TokenType = Token
}

struct AdminUser: Migration {
  typealias Database = PostgreSQLDatabase
  static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
    let password = try? BCrypt.hash("password")
    guard let hashedPassword = password else {
      fatalError("Failed to create admin user")
    }
    let user = User(name: "Admin", username: "admin", password: hashedPassword, email: "admin@localhost.local", userType: .admin)
    return user.save(on: conn).transform(to: ())
  }
  
  static func revert(on conn: PostgreSQLConnection) -> Future<Void> {
    return .done(on: conn)
  }
}

extension User: PasswordAuthenticatable {}
extension User: SessionAuthenticatable {}

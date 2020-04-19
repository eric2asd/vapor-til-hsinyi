import Vapor
import Crypto
import Fluent

struct UsersController: RouteCollection {
  
  let imageFolder = "ProfilePictures/"
  
  func boot(router: Router) throws {
    let userRoute = router.grouped("api", "users")
    userRoute.get(use: getAllHandler)
    userRoute.get(User.parameter, use: getHandler)
    userRoute.get(User.parameter, "acronyms", use: getAcronymsHandler)
    userRoute.get("acronyms", use: getAllUsersWithAcronyms)

    userRoute.post(SendUserVerificationPayload.self,
                   at: "send-verification-sms",
                   use: beginSMSVerification)
    userRoute.post(UserVerificationPayload.self,
                   at: "verify-sms-code",
                   use: validateVerificationCode)
    let basicAuthMiddleware = User.basicAuthMiddleware(using: BCryptDigest())
    let basicAuthGroup = userRoute.grouped(basicAuthMiddleware)
    basicAuthGroup.post("login", use: loginHandler)
    let tokenAuthMiddleware = User.tokenAuthMiddleware()
    let guardAuthMiddleware = User.guardAuthMiddleware()
    let tokenAuthGroup = userRoute .grouped(tokenAuthMiddleware, guardAuthMiddleware)
    tokenAuthGroup.post(User.self, use: createHandler)
    tokenAuthGroup.post(UploadProfileImage.self, at: "image", use: uploadHandler)
    tokenAuthGroup.delete(User.parameter, use: deleteHandler)
    tokenAuthGroup.post(UUID.parameter, "restore", use: restoreHandler)
    tokenAuthGroup.delete(User.parameter, "force", use: forceDeleteHandler)

    let usersV2Route = router.grouped("api", "v2", "users")
    // 2
    usersV2Route.get(User.parameter, use: getV2Handler)
  }
  
  func createHandler(_ req: Request, user: User) throws -> Future<User.Public> {
    user.password = try BCrypt.hash(user.password)
    return user.save(on: req).convertToPublic()
  }
  
  func getAllHandler(_ req: Request) throws -> Future<[User.Public]> {
    return User.query(on: req).decode(data: User.Public.self).all()
  }
  
  func getHandler(_ req: Request) throws -> Future<User.Public> {
    return try req.parameters.next(User.self).convertToPublic()
  }
  
  func getV2Handler(_ req: Request) throws -> Future<User.PublicV2> {
    return try req.parameters.next(User.self).convertToPublicV2()
  }
  
  func getAcronymsHandler(_ req: Request) throws -> Future<[Acronym]> {
    return try req
      .parameters.next(User.self)
      .flatMap(to: [Acronym].self) { user in
        try user.acronyms.query(on: req).all()
    }
  }
  func loginHandler(_ req: Request) throws -> Future<Token> {
    let user = try req.requireAuthenticated(User.self)
    let token = try Token.generate(for: user)
    return token.save(on: req)
  }
  
  func deleteHandler(_ req: Request) throws -> Future<HTTPStatus> {
    let requestUser = try req.requireAuthenticated(User.self)
    guard requestUser.userType == .admin else {
      throw Abort(.forbidden)
    }
    return try req.parameters
      .next(User.self)
      .delete(on: req)
      .transform(to: .noContent)
  }
  
  func uploadHandler(_ req: Request, image: UploadProfileImage) throws -> Future<User.Public> {
    let user = try req.requireAuthenticated(User.self)
    let workPath = try req.make(DirectoryConfig.self).workDir
    let name = try "\(user.requireID())-\(UUID().uuidString).jpg"
    let path = workPath + imageFolder + name
    FileManager().createFile(atPath: path, contents: image.image, attributes: nil)
    user.profilePicture = name
    return user.save(on: req).convertToPublic()
  }
  
  func restoreHandler(_ req: Request) throws -> Future<HTTPStatus> {
    let requestUser = try req.requireAuthenticated(User.self)
    guard requestUser.userType == .admin else {
      throw Abort(.forbidden)
    }

    let userID = try req.parameters.next(UUID.self)
    return User.query(on: req, withSoftDeleted: true)
      .filter(\.id == userID)
      .first()
      .flatMap(to: HTTPStatus.self) { user in
        guard let user = user else {
          throw Abort(.notFound)
        }
        return user.restore(on: req).transform(to: .ok)
    }
  }
  func forceDeleteHandler(_ req: Request) throws -> Future<HTTPStatus> {
    let requestUser = try req.requireAuthenticated(User.self)
    guard requestUser.userType == .admin else {
      throw Abort(.forbidden)
    }

    return try req.parameters
      .next(User.self)
      .flatMap(to: HTTPStatus.self) { user in
        return user.delete(force: true, on: req)
          .transform(to: .noContent)
    }
  }
  
  func getAllUsersWithAcronyms(_ req: Request) throws -> Future<[UserWithAcronyms]> {
    return User.query(on: req)
      .all()
      .flatMap(to: [UserWithAcronyms].self) { users in
        try users.map { user in
          try user.acronyms.query(on: req)
          .all()
            .map { acronyms in
              UserWithAcronyms(id: user.id, name: user.name, username: user.username, acronyms: acronyms)
          }
        }.flatten(on: req)
    }
  }
  
  // 1
  private func beginSMSVerification(
    _ req: Request,
    payload: SendUserVerificationPayload
  ) throws -> Future<SendUserVerificationResponse> {
    // 2
    let phoneNumber = payload.phoneNumber.removingInvalidCharacters
    // 3
    let code = String.randomDigits(ofLength: 6)
    let message = "Hello soccer lover! Your SoccerRadar code is \(code)"
    
    // 4
    return try req.make(SMSSender.self)
      .sendSMS(to: phoneNumber, message: message)
      // 5
      .flatMap(to: SMSVerificationAttempt.self) { success in
        guard success else {
          throw Abort(.internalServerError,
                      reason: "SMS could not be sent to \(phoneNumber)")
        }
        
        let smsAttempt =
          SMSVerificationAttempt(code: code,
                                 expiresAt: Date().addingTimeInterval(600),
                                 phoneNumber: phoneNumber)
        return smsAttempt.save(on: req)
    }
    .map { attempt in
      // 6
      let attemptId = try attempt.requireID()
      return SendUserVerificationResponse(phoneNumber: phoneNumber,
                                          attemptId: attemptId)
    }
  }
  
  // 1
  private func validateVerificationCode(_ req: Request,
                                        payload: UserVerificationPayload) throws
    -> Future<UserVerificationResponse> {
      // 2
      let code = payload.code
      let attemptId = payload.attemptId
      let phoneNumber = payload.phoneNumber.removingInvalidCharacters
      
      // 3
      return SMSVerificationAttempt.query(on: req)
        .filter(\.code == code)
        .filter(\.phoneNumber == phoneNumber)
        .filter(\.id == attemptId)
        .first()
        .flatMap(to: UserVerificationResponse.self) { attempt in
          // 4
          guard let expirationDate = attempt?.expiresAt else {
            return Future.map(on: req) {
              UserVerificationResponse(status: "invalid-code")
            }
          }
          
          guard expirationDate > Date() else {
            return Future.map(on: req) {
              UserVerificationResponse(status: "expired-code")
              
            }
          }
          
          // 5
          return Future.map(on: req) {
            UserVerificationResponse(status: "ok")
          }
      }
      
  }
  
}

struct UploadProfileImage: Content {
  var image: Data
}

extension UsersController {
  struct SendUserVerificationPayload: Codable, Content {
    let phoneNumber: String
  }
  
  struct SendUserVerificationResponse: Codable, Content {
    let phoneNumber: String
    let attemptId: UUID
  }
  
  struct UserVerificationPayload: Codable, Content {
    let attemptId: UUID //1
    let phoneNumber: String //2
    let code: String //3
  }
  
  struct UserVerificationResponse: Codable, Content {
    let status: String //4
  }
}

struct UserWithAcronyms: Content {
  let id: UUID?
  let name: String
  let username: String
  let acronyms: [Acronym]
}

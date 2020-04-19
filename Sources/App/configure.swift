import FluentPostgreSQL
import Vapor
import Leaf
import Authentication
import SendGrid

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
  // Register providers first
  try services.register(FluentPostgreSQLProvider())
  try services.register(LeafProvider())
  try services.register(AuthenticationProvider())
  try services.register(SendGridProvider())
  
  // Register routes to the router
  let router = EngineRouter.default()
  try routes(router)
  services.register(router, as: Router.self)
  
  // Register middleware
  var middlewares = MiddlewareConfig() // Create _empty_ middleware config
  middlewares.use(FileMiddleware.self) // Serves files from `Public/` directory
  middlewares.use(ErrorMiddleware.self) // Catches errors and converts to HTTP response
  middlewares.use(SessionsMiddleware.self)
  services.register(middlewares)
  
  // Configure a SQLite database
  // Register the configured SQLite database to the database config.
  var databases = DatabasesConfig()
  let databaseConfig: PostgreSQLDatabaseConfig
  if let url = Environment.get("DATABASE_URL") {
    databaseConfig = PostgreSQLDatabaseConfig(url: url)!
  } else {
    
    let hostname = Environment.get("DATABASE_HOSTNAME") ?? "localhost"
    let databaseName: String
    let databasePort: Int
    if env == .testing {
      databaseName = "vapor-test"
      if let testPort = Environment.get("DATABASE_PORT") {
        databasePort = Int(testPort) ?? 5433
      } else {
        databasePort = 5433
      }
    } else {
      databaseName = "vapor"
      databasePort = 5432
    }
    
      databaseConfig = PostgreSQLDatabaseConfig(
      hostname: hostname,
      port: databasePort,
      username: "vapor",
      database: databaseName,
      password: "password")
    
    
  }
  let database = PostgreSQLDatabase(config: databaseConfig)
  databases.add(database: database, as: .psql)
  
  services.register(databases)
  
  // Configure migrations
  var migrations = MigrationConfig()
  migrations.add(migration: UserType.self, database: .psql)
  migrations.add(model: User.self, database: .psql)
  migrations.add(model: Acronym.self, database: .psql)
  migrations.add(model: Category.self, database: .psql)
  migrations.add(model: AcronymCategoryPivot.self, database: .psql)
  migrations.add(model: Token.self, database: .psql)
  switch env {
  case .development, .testing:
    migrations.add(migration: AdminUser.self, database: .psql)
  default:
    break
  }
  migrations.add(model: ResetPasswordToken.self, database: .psql)
  migrations.add(model: SMSVerificationAttempt.self, database: .psql)
  migrations.add(migration: AddTwitterURLToUser.self, database: .psql)
  migrations.add(
    migration: MakeCategoriesUnique.self,
    database: .psql)
  services.register(migrations)
  
  var commandConfig = CommandConfig.default()
  commandConfig.useFluentCommands()
  services.register(commandConfig)
  
  config.prefer(LeafRenderer.self, for: ViewRenderer.self)
  config.prefer(MemoryKeyedCache.self, for: KeyedCache.self)
  
  guard let sendGridAPIKey = Environment.get("SENDGRID_API_KEY") else {
    fatalError("No Send Grid API Key specified")
  }
  let sendGridConfig = SendGridConfig(apiKey: sendGridAPIKey)
  services.register(sendGridConfig)
  
  services.register(NIOServerConfig.default(maxBodySize: 20_000_000))
  
  //1
  guard let accessKeyId = Environment.get("AWS_KEY_ID"),
    let secretKey = Environment.get("AWS_SECRET_KEY") else {
      fatalError("No AWS Key specified")
  }
  
  //2
  let snsSender = AWSSNSSender(accessKeyID: accessKeyId,
                               secretAccessKey: secretKey,
                               senderId: "TILAPP")
  //3
  services.register(snsSender, as: SMSSender.self)
  
}


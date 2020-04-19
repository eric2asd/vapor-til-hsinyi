//
//  UserTypes.swift
//  App
//
//  Created by 陳信毅 on 2020/4/19.
//

import FluentPostgreSQL

enum UserType: String, PostgreSQLEnum, PostgreSQLMigration {
  case admin
  case standard
  case restricted
}

//
//  AWSSNSSender.swift
//  App
//
//  Created by 陳信毅 on 2020/4/18.
//

import Vapor
import SNS

class AWSSNSSender {
  //1
  private let sns: SNS
  //2
  private let messageAttributes: [String: SNS.MessageAttributeValue]?

  init(accessKeyID: String, secretAccessKey: String, senderId: String?) {
    //3
    sns = SNS(accessKeyId: accessKeyID, secretAccessKey: secretAccessKey)

    //4
    messageAttributes = senderId.map { sender in
      let senderAttribute = SNS.MessageAttributeValue(binaryValue: nil,
                                                      dataType: "String",
                                                      stringValue: sender)
      return ["AWS.SNS.SMS.SenderID": senderAttribute]
    }
  }
}

extension AWSSNSSender: SMSSender {
  func sendSMS(to phoneNumber: String, message: String) throws -> Future<Bool> {
    //1
    let input = SNS.PublishInput(message: message,
                                 messageAttributes: messageAttributes,
                                 phoneNumber: phoneNumber)

    //2
    return sns.publish(input).map { $0.messageId != nil }
  }
}

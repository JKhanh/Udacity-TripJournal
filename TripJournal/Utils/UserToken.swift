//
//  UserToken.swift
//  TripJournal
//
//  Created by Khanh on 7/10/24.
//

import Foundation

class UserToken {
  private let accessTokenKey = "accessToken"
  private let tokenRetrievalTimeKey = "tokenRetrievalTime"
  private let tokenExpirationInterval: TimeInterval = 3600  // Time are set in Backend env but API don't return this so I'm hardcoding for now

  func saveAccessToken(_ token: String) {
    UserDefaults.standard.set(token, forKey: accessTokenKey)
    UserDefaults.standard.set(Date(), forKey: tokenRetrievalTimeKey)  // Save the current time
  }

  func getAccessToken() -> String? {
    guard let token = UserDefaults.standard.string(forKey: accessTokenKey),
      let retrievalDate = UserDefaults.standard.object(forKey: tokenRetrievalTimeKey) as? Date
    else {
      return nil  // No token stored or no retrieval time found
    }

    // Check if the token has expired (1 hour)
    let currentTime = Date()
    let timeElapsed = currentTime.timeIntervalSince(retrievalDate)

    if timeElapsed > tokenExpirationInterval {
      // Token has expired, invalidate it
      clearAccessToken()
      return nil
    } else {
      // Token is still valid
      return token
    }
  }

  // Clear the access token and the timestamp
  func clearAccessToken() {
    UserDefaults.standard.removeObject(forKey: accessTokenKey)
    UserDefaults.standard.removeObject(forKey: tokenRetrievalTimeKey)
  }
}

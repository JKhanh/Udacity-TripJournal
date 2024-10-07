//
//  JournalService+Live.swift
//  TripJournal
//
//  Created by Khanh on 2/10/24.
//

import Combine
import Foundation

enum HTTPMethods: String {
  case POST, GET, PUT, DELETE
}

enum MIMEType: String {
  case JSON = "application/json"
  case form = "application/x-www-form-urlencoded"
}

enum HTTPHeaders: String {
  case accept
  case contentType = "Content-Type"
  case authorization = "Authorization"
}

enum NetworkError: Error {
  case badUrl
  case badResponse
  case failedToDecodeResponse
  case unauthorized
}

class JournalServiceLive: JournalService {
  @Published var accessToken: String? = nil
  var isAuthenticated: AnyPublisher<Bool, Never> {
    $accessToken
      .map { $0 != nil }
      .eraseToAnyPublisher()
  }
  let urlSession = URLSession.shared
  var decoder = JSONDecoder()
  var encoder = JSONEncoder()
  let userToken = UserToken()

  init() {
    decoder.dateDecodingStrategy = .iso8601
    encoder.dateEncodingStrategy = .iso8601
    accessToken = userToken.getAccessToken()
  }

  enum EndPoints {
    static let base = "http://127.0.0.1:8000/"

    case register
    case login
    case trips
    case trip(Int)
    case events
    case event(Int)
    case medias
    case media(Int)

    private var stringValue: String {
      switch self {
      case .register:
        return createURLString(path: "register")
      case .login:
        return createURLString(path: "token")
      case .trips:
        return createURLString(path: "trips")
      case .trip(let id):
        return createURLString(path: "trips/\(id)")
      case .events:
        return createURLString(path: "events")
      case .event(let id):
        return createURLString(path: "events/\(id)")
      case .medias:
        return createURLString(path: "media")
      case .media(let id):
        return createURLString(path: "media/\(id)")
      }
    }

    private func createURLString(path: String) -> String {
      EndPoints.base + path
    }

    var url: URL? {
      return URL(string: stringValue)
    }
  }

  func register(username: String, password: String) async throws -> Token {
    let user = RegisterUser(username: username, password: password)
    let token: Token = try await performRequestWithReturn(
      url: EndPoints.register.url,
      method: .POST,
      mimeType: .JSON,
      body: try encoder.encode(user)
    )
    accessToken = token.accessToken
    userToken.saveAccessToken(token.accessToken)
    return token
  }

  func logIn(username: String, password: String) async throws -> Token {
    let token: Token = try await performRequestWithReturn(
      url: EndPoints.login.url,
      method: .POST,
      mimeType: .form,
      body: "grant_type=&username=\(username)&password=\(password)".data(using: .utf8)
    )
    accessToken = token.accessToken
    userToken.saveAccessToken(token.accessToken)
    return token
  }

  func logOut() {
    accessToken = nil
    userToken.clearAccessToken()
  }

  func createTrip(with request: TripCreate) async throws -> Trip {
    return try await performRequestWithReturn(
      url: EndPoints.trips.url,
      method: .POST,
      mimeType: .JSON,
      body: try encoder.encode(request)
    )
  }

  func getTrips() async throws -> [Trip] {
    return try await performRequestWithReturn(
      url: EndPoints.trips.url,
      method: .GET,
      mimeType: .JSON
    )
  }

  func getTrip(withId tripId: Trip.ID) async throws -> Trip {
    return try await performRequestWithReturn(
      url: EndPoints.trip(tripId).url,
      method: .GET,
      mimeType: .JSON
    )
  }

  func updateTrip(withId tripId: Trip.ID, and request: TripUpdate) async throws -> Trip {
    return try await performRequestWithReturn(
      url: EndPoints.trip(tripId).url,
      method: .PUT,
      mimeType: .JSON,
      body: try encoder.encode(request)
    )
  }

  func deleteTrip(withId tripId: Trip.ID) async throws {
    try await performRequest(
      url: EndPoints.trip(tripId).url,
      method: .DELETE,
      mimeType: .JSON
    ) { _ in

    }
  }

  func createEvent(with request: EventCreate) async throws -> Event {
    return try await performRequestWithReturn(
      url: EndPoints.events.url,
      method: .POST,
      mimeType: .JSON,
      body: try encoder.encode(request)
    )
  }

  func updateEvent(withId eventId: Event.ID, and request: EventUpdate) async throws -> Event {
    return try await performRequestWithReturn(
      url: EndPoints.event(eventId).url,
      method: .PUT,
      mimeType: .JSON,
      body: try encoder.encode(request)
    )
  }

  func deleteEvent(withId eventId: Event.ID) async throws {
    try await performRequest(
      url: EndPoints.event(eventId).url,
      method: .DELETE,
      mimeType: .JSON
    ) { _ in

    }
  }

  func createMedia(with request: MediaCreate) async throws -> Media {
    return try await performRequestWithReturn(
      url: EndPoints.medias.url,
      method: .POST,
      mimeType: .JSON,
      body: try encoder.encode(request)
    )
  }

  func deleteMedia(withId mediaId: Media.ID) async throws {
    try await performRequest(
      url: EndPoints.media(mediaId).url,
      method: .DELETE,
      mimeType: .JSON
    ) { _ in

    }
  }

  func performRequest(
    url: URL?,
    method: HTTPMethods,
    mimeType: MIMEType,
    body: Data? = nil,
    onSuccess: (Data) throws -> Void
  ) async throws {
    let request = try setupRequest(url: url, method: method, mimeType: mimeType, body: body)
    do {
      // Perform the request
      let (data, response) = try await urlSession.data(for: request)

      // Check the HTTP response
      guard let httpResponse = response as? HTTPURLResponse,
        (200...299).contains(httpResponse.statusCode)
      else {
        throw NetworkError.badResponse
      }
      try onSuccess(data)
    } catch {
      throw NetworkError.badResponse
    }
  }

  func performRequestWithReturn<T: Codable>(
    url: URL?,
    method: HTTPMethods,
    mimeType: MIMEType,
    body: Data? = nil
  ) async throws -> T {
    let request = try setupRequest(url: url, method: method, mimeType: mimeType, body: body)
    do {
      // Perform the request
      let (data, response) = try await urlSession.data(for: request)

      // Check the HTTP response
      guard let httpResponse = response as? HTTPURLResponse,
        (200...299).contains(httpResponse.statusCode)
      else {
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
          throw NetworkError.unauthorized
        }
        print(response)
        throw NetworkError.badResponse
      }
      do {
        let decodedResponse = try decoder.decode(T.self, from: data)
        return decodedResponse
      } catch {
        print("Unable to decode JSON: \(error.localizedDescription)")
        throw NetworkError.failedToDecodeResponse
      }
    } catch {
      throw NetworkError.badResponse
    }
  }

  func setupRequest(
    url: URL?,
    method: HTTPMethods,
    mimeType: MIMEType,
    body: Data? = nil
  ) throws -> URLRequest {
    guard let url else {
      throw NetworkError.badUrl
    }

    var request = URLRequest(url: url)

    request.httpMethod = method.rawValue
    request.setValue(mimeType.rawValue, forHTTPHeaderField: HTTPHeaders.contentType.rawValue)
    if let accessToken {
      request.setValue(
        "Bearer \(accessToken)", forHTTPHeaderField: HTTPHeaders.authorization.rawValue)
    }

    if let body = body {
      request.httpBody = body
    }

    return request
  }
}

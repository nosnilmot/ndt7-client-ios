//
//  NDT7Settings.swift
//  NDT7
//
//  Created by NietoGuillen, Miguel on 4/18/19.
//  Copyright © 2019 M-Lab. All rights reserved.
//

import Foundation

/// Settings needed for NDT7.
/// Can be used with default values: NDT7Settings()
public struct NDT7Settings {

    /// Timeouts
    public let timeout: NDT7Timeouts

    /// Skipt TLS certificate verification.
    public let skipTLSCertificateVerification: Bool

    /// Define all the headers needed for NDT7 request.
    public let headers: [String: String]


    public var allServers: [NDT7Server] = []

    public var currentServerIndex: Int?

      /// The server Locate API discovered to perform the test.
    public var currentServer: NDT7Server? {
        guard let selectedIndex = currentServerIndex,
              selectedIndex < allServers.count else { return nil }
        return allServers[selectedIndex]
    }

    public var currentDownloadPath: String? {
        return currentServer?.urls.downloadPath
    }

    public var currentUploadPath: String? {
        return currentServer?.urls.uploadPath
    }

    /// Initialization.
    public init(timeout: NDT7Timeouts = NDT7Timeouts(),
                skipTLSCertificateVerification: Bool = true,
                headers: [String: String] = [NDT7WebSocketConstants.Request.headerProtocolKey: NDT7WebSocketConstants.Request.headerProtocolValue]) {
        self.skipTLSCertificateVerification = skipTLSCertificateVerification
        self.timeout = timeout
        self.headers = headers
    }
}

///// URL settings.
//public struct NDT7URL {
//
//    /// Mlab Server:
//    public var server: NDT7Server?
//
//    /// Server to connect.
//    public var hostname: String
//
//    /// Patch for download test.
//    public let downloadPath: String
//
//    /// Patch for upload test.
//    public let uploadPath: String
//
//    /// Define if it is wss or ws.
//    public let wss: Bool
//
//    /// Download URL
//    public var download: String {
//        return "\(wss ? "wss" : "ws")\("://")\(hostname)\(downloadPath)"
//    }
//
//    /// Upload URL
//    public var upload: String {
//        return "\(wss ? "wss" : "ws")\("://")\(hostname)\(uploadPath)"
//    }
//
//    /// Initialization.
//    public init(hostname: String,
//                downloadPath: String = NDT7WebSocketConstants.Request.downloadPath,
//                uploadPath: String = NDT7WebSocketConstants.Request.uploadPath,
//                wss: Bool = true) {
//        self.hostname = hostname
//        self.downloadPath = downloadPath
//        self.uploadPath = uploadPath
//        self.wss = wss
//    }
//
//
//}

/// Timeout settings.
public struct NDT7Timeouts {

    /// Define the interval between messages.
    /// When downloading, the server is expected to send measurement to the client,
    /// and when uploading, conversely, the client is expected to send measurements to the server.
    /// Measurements SHOULD NOT be sent more frequently than every 250 ms
    /// This parameter deine the frequent to send messages.
    /// If it is initialize with less than 250 ms, it's going to be overwritten to 250 ms
    public let measurement: TimeInterval

    /// ioTimeout is the timeout in seconds for I/O operations.
    public let ioTimeout: TimeInterval

    /// Define the max among of time used for a download test before to force to finish.
    public let downloadTimeout: TimeInterval

    /// Define the max among of time used for a upload test before to force to finish.
    public let uploadTimeout: TimeInterval

    /// Initialization.
    public init(measurement: TimeInterval = NDT7WebSocketConstants.Request.updateInterval,
                ioTimeout: TimeInterval = NDT7WebSocketConstants.Request.ioTimeout,
                downloadTimeout: TimeInterval = NDT7WebSocketConstants.Request.downloadTimeout,
                uploadTimeout: TimeInterval = NDT7WebSocketConstants.Request.uploadTimeout) {
        self.measurement = measurement >= NDT7WebSocketConstants.Request.updateInterval ? measurement : NDT7WebSocketConstants.Request.updateInterval
        self.ioTimeout = ioTimeout
        self.downloadTimeout = downloadTimeout
        self.uploadTimeout = uploadTimeout
    }
}

/// Locate API V2 response object
public struct LocateAPIResponse: Codable {
    public var results: [NDT7Server]
}

/// Locate API V2 Mlab NDT7 Server.
public struct NDT7Server: Codable {

    /// The URL of the machine.
    public var machine: String

    /// Location of the server.
    public var location: NDT7Location?

    /// URLS from which the client can upload/download.
    public var urls: NDT7URLs
}

/// Locate API V2 client location.
public struct NDT7Location: Codable {
    /// Country of the
    public var country: String?

    /// city
    public var city: String?
}

/// Locate API V2 URLs.
/// This struct contains the complete download/upload URL for running a measurement.
public struct NDT7URLs: Codable {
    public var downloadPath: String
    public var uploadPath: String
    public var insecureDownloadPath: String
    public var insecureUploadPath: String

    enum CodingKeys: String, CodingKey {
        case downloadPath = "wss:///ndt/v7/download"
        case uploadPath = "wss:///ndt/v7/upload"
        case insecureDownloadPath = "ws:///ndt/v7/download"
        case insecureUploadPath = "ws:///ndt/v7/upload"
    }
}

/// This extension provides helper methods to discover Mlab servers availables.
extension NDT7Server {

    /// Discover the closer Mlab server available or using geo location to get a random server from a list of the closer servers.
    /// - parameter session: URLSession object used to request servers, using URLSession.shared object as default session.
    /// - parameter retry: Number of times to retry.
    /// - parameter completion: callback to get the NDT7Server and error message.
    /// - parameter servers: An array of NDT7Server objects representing the Mlab server located nearby.
    /// - parameter error: if any error happens, this parameter returns the error.
    public static func discover<T: URLSessionNDT7>(session: T = URLSession.shared as! T,
                                                   retry: UInt = 0,
                                                   useNDT7ServerCache: Bool = false,
                                                   _ completion: @escaping (_ server: [NDT7Server]?, _ error: NSError?) -> Void) -> URLSessionTaskNDT7 {
//        let retry = min(retry, 4)
        let request = Networking.urlRequest(NDT7WebSocketConstants.MlabServerDiscover.url)
        let task = session.dataTask(with: request as URLRequest) { (data, _, error) -> Void in
            OperationQueue.current?.name = "net.measurementlab.NDT7.MlabServer.discover"
            guard error?.localizedDescription != "cancelled" else {
                completion(nil, NDT7TestConstants.cancelledError)
                return
            }
            guard error == nil, let data = data else {
//                if retry > 0 {
//                    logNDT7("NDT7 Mlab error, cannot find a suitable mlab server, retry: \(retry)", .info)
//                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
//                        _ = discover(session: session,
//                                     retry: retry - 1,
//                                     useNDT7ServerCache: useNDT7ServerCache,
//                                     completion)
//                    }
//                } else if retry == 0, let server = lastServer {
//                    logNDT7("NDT7 Mlab server \(server.fqdn!)\(error == nil ? "" : " error: \(error!.localizedDescription)")", .info)
//                    completion(server, server.fqdn == nil ? NDT7WebSocketConstants.MlabServerDiscover.noMlabServerError : nil)
//                }
                completion(nil, NDT7WebSocketConstants.MlabServerDiscover.noMlabServerError)
                return
            }

//            if let server = decode(data: data, fromUrl: request.url?.absoluteString), server.fqdn != nil  && server.fqdn! != "" {
//                lastServer = server
//                logNDT7("NDT7 Mlab server \(server.fqdn!)\(error == nil ? "" : " error: \(error!.localizedDescription)")", .info)
//                completion(server, server.fqdn == nil ? NDT7WebSocketConstants.MlabServerDiscover.noMlabServerError : nil)
//            } else if retry > 0 {
//                logNDT7("NDT7 Mlab cannot find a suitable mlab server, retry: \(retry)", .info)
//                DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
//                    _ = discover(session: session,
//                                 retry: retry - 1,
//                                 useNDT7ServerCache: useNDT7ServerCache,
//                                 completion)
//                }
//            } else if retry == 0, useNDT7ServerCache, let server = lastServer {
//                logNDT7("NDT7 Mlab server \(server.fqdn!)\(error == nil ? "" : " error: \(error!.localizedDescription)")", .info)
//                completion(server, server.fqdn == nil ? NDT7WebSocketConstants.MlabServerDiscover.noMlabServerError : nil)
//            } else {
//                logNDT7("NDT7 Mlab cannot find a suitable mlab server, retry: \(retry)", .info)
//                completion(nil, NDT7WebSocketConstants.MlabServerDiscover.noMlabServerError)
//            }

          if let apiResponse = try? JSONDecoder().decode(LocateAPIResponse.self, from: data) {
            completion(apiResponse.results, nil)
            return
          }
        }
        task.resume()
        return task
    }

    static func decode(data: Data?, fromUrl url: String?) -> NDT7Server? {
        guard let data = data, let url = url else { return nil }
        switch url {
        case NDT7WebSocketConstants.MlabServerDiscover.url:
            return try? JSONDecoder().decode(NDT7Server.self, from: data)
//        case NDT7WebSocketConstants.MlabServerDiscover.urlWithGeoOption:
//            let decoded = try? JSONDecoder().decode([NDT7Server].self, from: data)
//            let server = decoded?.first(where: { (server) -> Bool in
//                return server.fqdn != nil && !server.fqdn!.isEmpty
//            })
//            return server
        default:
            return nil
        }
    }
}

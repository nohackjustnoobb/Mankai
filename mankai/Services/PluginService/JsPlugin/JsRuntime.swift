//
//  JsRuntime.swift
//  mankai
//
//  Created by Travis XU on 23/6/2025.
//

import Foundation
import WebKit

let JS_LOG = """
function log(mesg, from = "JS") {
  window.webkit.messageHandlers.DEFAULT_BRIDGE.postMessage({
    method: "log",
    params: {
      from: from,
      message: mesg,
    },
  });
}
"""

let JS_FETCH = """
async function fetch(url, options = {}) {
  let headers = options.headers || {};
  if (headers instanceof Headers)
    headers = Object.fromEntries(headers.entries());

  const params = {
    url: url,
    method: options.method || "GET",
    headers: headers,
    body: options.body,
  };

  try {
    const result =
      await window.webkit.messageHandlers.DEFAULT_BRIDGE.postMessage({
        method: "fetch",
        params: params,
      });

    const headers = {
      get: (name) => result.headers[name] || result.headers[name.toLowerCase()],
      has: (name) =>
        name in result.headers || name.toLowerCase() in result.headers,
      entries: () => Object.entries(result.headers),
      keys: () => Object.keys(result.headers),
      values: () => Object.values(result.headers),
    };

    const binaryString = atob(result.data);
    const bytes = new Uint8Array(binaryString.length);
    for (let i = 0; i < binaryString.length; i++) {
      bytes[i] = binaryString.charCodeAt(i);
    }

    return {
      ok: result.ok,
      status: result.status,
      statusText: result.statusText,
      headers: headers,
      url: result.url,
      text: async () => new TextDecoder().decode(bytes),
      json: async () => JSON.parse(new TextDecoder().decode(bytes)),
      blob: async () => new Blob([bytes]),
      arrayBuffer: async () => bytes.buffer,
    };
  } catch (error) {
    throw new Error(`Fetch failed: ${error.message}`);
  }
}
"""

enum Method: String {
    case log
    case fetch
    case setConfig
}

class JsRuntime: NSObject {
    static let shared = JsRuntime()

    private var webview: WKWebView?

    @MainActor
    private func initWebview() async {
        if webview == nil {
            webview = WKWebView(frame: .zero)
            webview?.configuration.userContentController.addScriptMessageHandler(
                self, contentWorld: .defaultClient, name: "DEFAULT_BRIDGE")
        }
    }

    /// Executes JavaScript in the hidden WKWebView using async/await
    /// - Parameter js: The JavaScript code to execute
    /// - Returns: The result of the JavaScript execution
    @MainActor
    public func execute(_ js: String, from: String? = nil, plugin: JsPlugin? = nil) async throws
        -> Any?
    {
        await initWebview()

        guard let webview else {
            throw NSError(
                domain: "JsRuntime", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "WebView not initialized"])
        }

        // Inject functions
        let injectedJs = inject(js, from: from, plugin: plugin)

        return try await webview.callAsyncJavaScript(injectedJs, contentWorld: .defaultClient)
    }

    private func inject(_ js: String, from: String? = nil, plugin: JsPlugin? = nil) -> String {
        // TODO: inject getValue and setValue functions
        var injectedJs = JS_LOG + JS_FETCH

        if let plugin = plugin {
            let configValuesArray = plugin.configValues.map { configValue in
                [
                    "key": configValue.key,
                    "value": configValue.value,
                ]
            }

            let configValuesJson: String
            do {
                let jsonData = try JSONSerialization.data(
                    withJSONObject: configValuesArray, options: [])
                configValuesJson = String(data: jsonData, encoding: .utf8) ?? "[]"
            } catch {
                configValuesJson = "[]"
            }

            let getConfigs = """
            function getConfigs() {
                return \(configValuesJson);
            }
            """

            injectedJs += getConfigs
        }

        var from = plugin?.id ?? from
        from = from == nil ? "undefined" : "\"\(from!)\""

        // Override console.log
        injectedJs += "console.log = (...m) => log(m.join(' '), \(from!));"

        injectedJs += js
        return injectedJs
    }
}

extension JsRuntime: WKScriptMessageHandlerWithReply {
    private func handleFetch(_ params: [String: Any]) async throws -> [String: Any] {
        guard let url = params["url"] as? String else {
            throw NSError(
                domain: "JsRuntime", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Missing URL parameter"])
        }

        guard let requestURL = URL(string: url) else {
            throw NSError(
                domain: "JsRuntime", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: requestURL)

        let method = params["method"] as? String ?? "GET"
        request.httpMethod = method

        if let headers = params["headers"] as? [String: String] {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        if let body = params["body"] as? String {
            request.httpBody = body.data(using: .utf8)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(
                domain: "JsRuntime", code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
        }

        let responseTextBase64 = data.base64EncodedString()

        var responseHeaders: [String: String] = [:]
        for (key, value) in httpResponse.allHeaderFields {
            if let keyString = key as? String, let valueString = value as? String {
                responseHeaders[keyString] = valueString
            }
        }

        return [
            "ok": httpResponse.statusCode >= 200 && httpResponse.statusCode < 300,
            "status": httpResponse.statusCode,
            "statusText": HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode),
            "headers": responseHeaders,
            "data": responseTextBase64,
            "url": httpResponse.url?.absoluteString ?? url,
        ]
    }

    func userContentController(
        _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
    ) async -> (Any?, String?) {
        let body = message.body as! [String: Any]
        let method = Method(rawValue: body["method"] as! String)
        let params = body["params"] as! [String: Any]

        switch method {
        case .log:
            let from = params["from"] as! String
            let message = params["message"] as! String
            print("[\(from)] \(message)")
        case .fetch:
            do {
                let resp = try await handleFetch(params)

                return (resp, nil)
            } catch {
                return (nil, error.localizedDescription)
            }
        default:
            fatalError("Unexpected Method")
        }

        return (nil, nil)
    }
}

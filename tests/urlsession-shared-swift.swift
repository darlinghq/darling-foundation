// URLSession.shared, HTTPURLResponse and URLResponse properties from Swift (VibeDarling/darling#948).
// Needs darling-cfnetwork's NSURLSession data tasks (VibeDarling/darling#947) and an HTTP server on
// the host that serves a file with the exact body "hello from host\n", e.g.
//   printf 'hello from host\n' > dir/text.txt && python3 -m http.server 8765 -b 127.0.0.1 -d dir
// usage: urlsession-shared-swift http://127.0.0.1:8765/text.txt
import Foundation

var failures = 0
func expect(_ condition: Bool, _ message: String) {
    if !condition {
        print("FAIL: \(message)")
        failures += 1
    }
}

guard CommandLine.arguments.count == 2, let url = URL(string: CommandLine.arguments[1]) else {
    print("usage: urlsession-shared-swift <url of a file containing \"hello from host\\n\">")
    exit(2)
}

func fetch(_ url: URL) -> (Data?, URLResponse?, Error?) {
    let done = DispatchSemaphore(value: 0)
    var result: (Data?, URLResponse?, Error?) = (nil, nil, nil)
    let session: URLSession = URLSession.shared
    let task = session.dataTask(with: url) { data, response, error in
        result = (data, response, error)
        done.signal()
    }
    task.resume()
    if done.wait(timeout: .now() + 20) == .timedOut {
        print("FAIL: no completion for \(url) within 20 s")
        exit(1)
    }
    return result
}

let (data, response, error) = fetch(url)
expect(error == nil, "no error, got \(String(describing: error))")
expect(data.map { String(decoding: $0, as: UTF8.self) } == "hello from host\n", "body, got \(String(describing: data))")

let http = response as? HTTPURLResponse
expect(http != nil, "response is an HTTPURLResponse")
expect(http?.statusCode == 200, "statusCode, got \(String(describing: http?.statusCode))")
expect(http?.allHeaderFields["Content-Length"] as? String == "16", "allHeaderFields")
let plain: URLResponse? = response
expect(plain?.url == url, "url, got \(String(describing: plain?.url))")
expect(plain?.mimeType == "text/plain", "mimeType, got \(String(describing: plain?.mimeType))")
expect(plain?.expectedContentLength == 16, "expectedContentLength")
expect(plain?.suggestedFilename != nil, "suggestedFilename")

let built = HTTPURLResponse(url: url, statusCode: 418, httpVersion: "HTTP/1.1", headerFields: ["X-Test": "1"])
expect(built?.statusCode == 418 && built?.allHeaderFields["X-Test"] as? String == "1", "HTTPURLResponse initializer")

let refused = fetch(URL(string: "http://127.0.0.1:1/")!)
let refusedError = refused.2 as? URLError
expect(refusedError?.code == .cannotConnectToHost, "refused connection error, got \(String(describing: refused.2))")
expect(refused.0 == nil && refused.1 == nil, "no data or response on error")

if failures == 0 {
    print("PASS: URLSession.shared data task from Swift")
}
exit(failures == 0 ? 0 : 1)

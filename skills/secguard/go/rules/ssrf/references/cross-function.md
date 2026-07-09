# SSRF — 跨函数追踪 (Go)

适用于 `go.web.ssrf` skill（CWE-918）。max depth 1。

## 场景一: HTTP 参数 → http.Get

```go
func proxyHandler(w http.ResponseWriter, r *http.Request) {
    target := r.URL.Query().Get("url")    // Source
    fetchURL(target)
}

func fetchURL(url string) {
    resp, err := http.Get(url)            // Sink: SSRF
}
```

## 场景二: ReverseProxy 动态目标

```go
func main() {
    http.HandleFunc("/proxy/", proxyPass)
}

func proxyPass(w http.ResponseWriter, r *http.Request) {
    target := r.URL.Query().Get("backend")           // Source
    proxy := httputil.NewSingleHostReverseProxy(target)  // Sink: SSRF
    proxy.ServeHTTP(w, r)
}
```

## 场景三: Webhook URL 回调

```go
func webhookHandler(w http.ResponseWriter, r *http.Request) {
    callbackURL := r.FormValue("callback_url")       // Source
    triggerWebhook(callbackURL, eventData)
}

func triggerWebhook(url string, data interface{}) {
    body, _ := json.Marshal(data)
    http.Post(url, "application/json", bytes.NewReader(body))  // Sink
}
```

## 深度限制

- max depth 1: 追踪 URL 来源到 HTTP 请求
- `http.Get`, `http.Post`, `http.NewRequest`, `http.Client.Do`, `httputil.ReverseProxy` 均为 Sink 点

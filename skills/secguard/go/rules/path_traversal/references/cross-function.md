# Path Traversal — 跨函数追踪 (Go)

适用于 `go.system.path-traversal` skill（CWE-22）。max depth 1。

## 场景一: HTTP 参数 → 文件读取

```go
func serveFile(w http.ResponseWriter, r *http.Request) {
    name := r.URL.Query().Get("file")    // Source
    content, err := readFileByName(name)
    // ...
}

func readFileByName(path string) ([]byte, error) {
    return os.ReadFile("/var/www/" + path)  // Sink: 路径拼接
}
```

## 场景二: 路径组装跨函数

```go
func downloadHandler(w http.ResponseWriter, r *http.Request) {
    fileID := r.URL.Query().Get("id")     // Source
    fullPath := buildPath(fileID)
    http.ServeFile(w, r, fullPath)
}

func buildPath(id string) string {
    return filepath.Join(uploadDir, id)   // Join 不做安全校验
}
```

## 场景三: Zip Slip 跨函数

```go
func extractZip(r io.Reader) error {
    archive, _ := zip.NewReader(r, size)
    for _, f := range archive.File {
        saveExtracted(f)                    // 遍历每个条目
    }
}

func saveExtracted(f *zip.File) {
    target := filepath.Join(extractDir, f.Name)  // Sink: Zip Slip
    os.OpenFile(target, ...)
}
```

## 场景四: 路径遍历 → 写文件

```go
func uploadHandler(w http.ResponseWriter, r *http.Request) {
    file, header, _ := r.FormFile("file")    // Source: 上传文件名
    saveFile(header.Filename, file)
}

func saveFile(filename string, src io.Reader) {
    dst, _ := os.Create("/uploads/" + filename)  // Sink: 写路径遍历
    io.Copy(dst, src)
}
```

## 深度限制

- max depth 1: 从用户输入到文件操作的一层调用链
- `filepath.Join` + `os.Open` 的组合即使跨函数也应追踪
- Go 的 `http.ServeFile`/`http.FileServer` 是常见 Sink 点

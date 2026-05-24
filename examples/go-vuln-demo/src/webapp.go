package main

import (
	"fmt"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"path/filepath"
	"sync"
)

// VULNERABILITY [CWE-918]: SSRF — http.Get with user-controlled URL
// VULNERABILITY [CWE-22]: Zip Slip — filepath.Join without Clean
// VULNERABILITY [CWE-362]: Race Condition — concurrent map access
// webapp.go — Web 应用漏洞 (SSRF/Path/ZipSlip/Concurrency)

// BadFetchURL makes an HTTP request to a user-supplied URL.
// VULNERABILITY [CWE-918]: SSRF — user-supplied URL without validation
func BadFetchURL(rawURL string) (*http.Response, error) {
	return http.Get(rawURL)
}

// BadReverseProxy sets up a reverse proxy without target validation.
// VULNERABILITY [CWE-918]: SSRF — ReverseProxy target from user input
func BadReverseProxy(userTarget string) http.Handler {
	target, _ := url.Parse(userTarget)
	proxy := httputil.NewSingleHostReverseProxy(target)
	return proxy
}

// BadUnzip writes zip entries without path validation.
// VULNERABILITY [CWE-22]: Zip Slip — filepath.Join without Clean/sandbox check
func BadUnzip(destDir string, entryName string, data []byte) error {
	targetPath := filepath.Join(destDir, entryName)
	// No Clean, no prefix check — ../../etc/cron.d/backdoor works
	return os.WriteFile(targetPath, data, 0644)
}

// BadConcurrentMap shows unprotected map access across goroutines.
// VULNERABILITY [CWE-362]: concurrent map read/write without sync — leads to fatal error
var sharedMap = make(map[string]int)

func BadConcurrentAccess() {
	var wg sync.WaitGroup

	// Writer goroutine
	wg.Add(1)
	go func() {
		defer wg.Done()
		for i := 0; i < 1000; i++ {
			sharedMap[fmt.Sprintf("key_%d", i)] = i // DATA RACE
		}
	}()

	// Reader goroutine
	wg.Add(1)
	go func() {
		defer wg.Done()
		for i := 0; i < 1000; i++ {
			_ = sharedMap[fmt.Sprintf("key_%d", i)] // DATA RACE
		}
	}()

	wg.Wait()
}

// GoodFetchURL validates the target URL against an allowlist.
func GoodFetchURL(rawURL string) (*http.Response, error) {
	u, err := url.Parse(rawURL)
	if err != nil {
		return nil, err
	}
	// Validate scheme and host
	if u.Scheme != "https" {
		return nil, fmt.Errorf("only https allowed")
	}
	// Check against internal IP blocklist
	return http.Get(u.String())
}

// GoodUnzip validates entry path before writing.
func GoodUnzip(destDir string, entryName string, data []byte) error {
	clean := filepath.Clean(entryName)
	if filepath.IsAbs(clean) || clean[0:2] == ".." {
		return fmt.Errorf("invalid entry path: %s", entryName)
	}
	targetPath := filepath.Join(destDir, clean)
	return os.WriteFile(targetPath, data, 0644)
}

// GoodConcurrentAccess uses sync.RWMutex.
var (
	safeMap   = make(map[string]int)
	safeMutex sync.RWMutex
)

func GoodConcurrentAccess() {
	var wg sync.WaitGroup

	wg.Add(1)
	go func() {
		defer wg.Done()
		for i := 0; i < 1000; i++ {
			safeMutex.Lock()
			safeMap[fmt.Sprintf("key_%d", i)] = i
			safeMutex.Unlock()
		}
	}()

	wg.Add(1)
	go func() {
		defer wg.Done()
		for i := 0; i < 1000; i++ {
			safeMutex.RLock()
			_ = safeMap[fmt.Sprintf("key_%d", i)]
			safeMutex.RUnlock()
		}
	}()

	wg.Wait()
}

/**
 * webapp.go — Web security vulnerability examples (Go)
 *
 * VULNERABILITIES:
 *   - CWE-89:  SQL injection — string concatenation (line 20)
 *   - CWE-918: SSRF — user-controlled URL fetch (line 34)
 *   - CWE-79:  XSS — output without escaping (line 46)
 *   - CWE-352: CSRF — no token validation (line 57)
 *   - CWE-287: Auth bypass — missing auth check (line 70)
 *   - CWE-639: IDOR — no ownership check (line 81)
 *   - CWE-611: XXE — insecure XML parsing (line 92)
 *   - CWE-347: JWT misuse — weak HMAC secret (line 106)
 *   - CWE-601: Open redirect — user-controlled Location (line 120)
 */

package main

import (
	"database/sql"
	"encoding/xml"
	"fmt"
	"io"
	"io/ioutil"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"time"

	"github.com/dgrijalva/jwt-go"
	_ "github.com/go-sql-driver/mysql"
)

var db *sql.DB

func main() {
	http.HandleFunc("/validate", validateInput)
	http.HandleFunc("/upload", handleUpload)
	http.HandleFunc("/admin/dashboard", adminDashboard)
	http.HandleFunc("/profile", userProfile)
	http.HandleFunc("/process", processItems)
	http.HandleFunc("/user", getUser)
	http.HandleFunc("/fetch", fetchURL)
	http.HandleFunc("/search", searchXSS)
	http.HandleFunc("/transfer", transferCSRF)
	http.HandleFunc("/admin", adminPanel)
	http.HandleFunc("/api/user/", getUserProfile)
	http.HandleFunc("/api/xml", parseXML)
	http.HandleFunc("/api/login", loginJWT)
	http.HandleFunc("/redirect", redirectOpen)
	http.ListenAndServe(":8080", nil)
}

// CWE-89: SQL Injection
func getUser(w http.ResponseWriter, r *http.Request) {
	username := r.URL.Query().Get("username")
	// VULNERABILITY [CWE-89]: SQL injection — string concatenation
	query := "SELECT * FROM users WHERE username = '" + username + "'"
	rows, _ := db.Query(query)
	fmt.Fprintf(w, "User query: %s", query)
}

// CWE-918: SSRF
func fetchURL(w http.ResponseWriter, r *http.Request) {
	url := r.URL.Query().Get("url")
	// VULNERABILITY [CWE-918]: SSRF — user-controlled URL fetch
	resp, _ := http.Get(url)
	body, _ := ioutil.ReadAll(resp.Body)
	resp.Body.Close()
	fmt.Fprintf(w, "Fetched: %s", string(body))
}

// CWE-79: XSS
func searchXSS(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query().Get("q")
	// VULNERABILITY [CWE-79]: XSS — reflecting user input without escaping
	w.Header().Set("Content-Type", "text/html")
	fmt.Fprintf(w, "<html><body>Search results for: %s</body></html>", q)
}

// CWE-352: CSRF
func transferCSRF(w http.ResponseWriter, r *http.Request) {
	if r.Method == "POST" {
		// VULNERABILITY [CWE-352]: CSRF — no anti-CSRF token check
		amount := r.FormValue("amount")
		executeTransfer(amount)
		fmt.Fprintf(w, "Transferred $%s", amount)
	}
}

func executeTransfer(amount string) {
	fmt.Printf("Transferring $%s\n", amount)
}

// CWE-287: Auth Bypass
func adminPanel(w http.ResponseWriter, r *http.Request) {
	// VULNERABILITY [CWE-287]: Auth bypass — no authentication required
	fmt.Fprintf(w, "Admin Panel — sensitive data")
}

// CWE-639: IDOR
func getUserProfile(w http.ResponseWriter, r *http.Request) {
	// Parse user ID from URL
	parts := strings.Split(r.URL.Path, "/")
	userID := parts[len(parts)-1] // last segment
	// VULNERABILITY [CWE-639]: IDOR — no ownership verification
	fmt.Fprintf(w, `{"userId":%s,"ssn":"123-45-6789"}`, userID)
}

// CWE-611: XXE
func parseXML(w http.ResponseWriter, r *http.Request) {
	body, _ := ioutil.ReadAll(r.Body)
	// VULNERABILITY [CWE-611]: XXE — XML parser allows external entities
	var data interface{}
	xml.Unmarshal(body, &data) // default decoder allows entities
	fmt.Fprintf(w, "Parsed XML")
}

// CWE-347: JWT Weak Secret
func loginJWT(w http.ResponseWriter, r *http.Request) {
	username := r.URL.Query().Get("username")
	// VULNERABILITY [CWE-347]: JWT with weak hardcoded secret
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"user":  username,
		"admin": true,
		"exp":   time.Now().Add(time.Hour * 72).Unix(),
	})
	tokenString, _ := token.SignedString([]byte("secret"))
	fmt.Fprintf(w, `{"token":"%s"}`, tokenString)
}

// CWE-20: Improper Input Validation
func validateInput(w http.ResponseWriter, r *http.Request) {
	val := r.URL.Query().Get("val")
	// VULNERABILITY [CWE-20]: No input validation
	fmt.Fprintf(w, "Processed: %s", val)
}

// CWE-434: Unrestricted File Upload
func handleUpload(w http.ResponseWriter, r *http.Request) {
	r.ParseMultipartForm(32 << 20)
	file, header, _ := r.FormFile("file")
	defer file.Close()
	// VULNERABILITY [CWE-434]: No type/size validation
	out, _ := os.Create("/uploads/" + header.Filename)
	defer out.Close()
	io.Copy(out, file)
	fmt.Fprintf(w, "uploaded")
}

// CWE-862: Missing Authorization
func adminDashboard(w http.ResponseWriter, r *http.Request) {
	// VULNERABILITY [CWE-862]: No authorization check
	fmt.Fprintf(w, "Sensitive admin dashboard data")
}

// CWE-306: Missing Authentication
func userProfile(w http.ResponseWriter, r *http.Request) {
	// VULNERABILITY [CWE-306]: No authentication required
	fmt.Fprintf(w, `{"email":"user@example.com"}`)
}

// CWE-400: Resource Exhaustion
func processItems(w http.ResponseWriter, r *http.Request) {
	// VULNERABILITY [CWE-400]: No limit on processing
	items := r.URL.Query()["items"]
	for _, item := range items {
		time.Sleep(100 * time.Millisecond)
		fmt.Fprintf(w, "processed:%s ", item)
	}
}

// CWE-601: Open Redirect
func redirectOpen(w http.ResponseWriter, r *http.Request) {
	url := r.URL.Query().Get("url")
	// VULNERABILITY [CWE-601]: Open redirect — no URL validation
	w.Header().Set("Location", url)
	w.WriteHeader(http.StatusFound)
}

// CWE-94: Command injection (Go equivalent)
func execCmd(w http.ResponseWriter, r *http.Request) {
	cmd := r.URL.Query().Get("cmd")
	// VULNERABILITY [CWE-94]: Command injection
	out, _ := exec.Command("sh", "-c", cmd).Output()
	fmt.Fprintf(w, "Result: %s", string(out))
}

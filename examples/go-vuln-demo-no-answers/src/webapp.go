/**
 * webapp.go — Web security vulnerability examples (Go)
 *










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


func getUser(w http.ResponseWriter, r *http.Request) {
	username := r.URL.Query().Get("username")

	query := "SELECT * FROM users WHERE username = '" + username + "'"
	rows, _ := db.Query(query)
	fmt.Fprintf(w, "User query: %s", query)
}


func fetchURL(w http.ResponseWriter, r *http.Request) {
	url := r.URL.Query().Get("url")

	resp, _ := http.Get(url)
	body, _ := ioutil.ReadAll(resp.Body)
	resp.Body.Close()
	fmt.Fprintf(w, "Fetched: %s", string(body))
}


func searchXSS(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query().Get("q")

	w.Header().Set("Content-Type", "text/html")
	fmt.Fprintf(w, "<html><body>Search results for: %s</body></html>", q)
}


func transferCSRF(w http.ResponseWriter, r *http.Request) {
	if r.Method == "POST" {

		amount := r.FormValue("amount")
		executeTransfer(amount)
		fmt.Fprintf(w, "Transferred $%s", amount)
	}
}

func executeTransfer(amount string) {
	fmt.Printf("Transferring $%s\n", amount)
}


func adminPanel(w http.ResponseWriter, r *http.Request) {

	fmt.Fprintf(w, "Admin Panel — sensitive data")
}


func getUserProfile(w http.ResponseWriter, r *http.Request) {
	// Parse user ID from URL
	parts := strings.Split(r.URL.Path, "/")
	userID := parts[len(parts)-1] // last segment

	fmt.Fprintf(w, `{"userId":%s,"ssn":"123-45-6789"}`, userID)
}


func parseXML(w http.ResponseWriter, r *http.Request) {
	body, _ := ioutil.ReadAll(r.Body)

	var data interface{}
	xml.Unmarshal(body, &data) // default decoder allows entities
	fmt.Fprintf(w, "Parsed XML")
}


func loginJWT(w http.ResponseWriter, r *http.Request) {
	username := r.URL.Query().Get("username")

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"user":  username,
		"admin": true,
		"exp":   time.Now().Add(time.Hour * 72).Unix(),
	})
	tokenString, _ := token.SignedString([]byte("secret"))
	fmt.Fprintf(w, `{"token":"%s"}`, tokenString)
}


func validateInput(w http.ResponseWriter, r *http.Request) {
	val := r.URL.Query().Get("val")

	fmt.Fprintf(w, "Processed: %s", val)
}


func handleUpload(w http.ResponseWriter, r *http.Request) {
	r.ParseMultipartForm(32 << 20)
	file, header, _ := r.FormFile("file")
	defer file.Close()

	out, _ := os.Create("/uploads/" + header.Filename)
	defer out.Close()
	io.Copy(out, file)
	fmt.Fprintf(w, "uploaded")
}


func adminDashboard(w http.ResponseWriter, r *http.Request) {

	fmt.Fprintf(w, "Sensitive admin dashboard data")
}


func userProfile(w http.ResponseWriter, r *http.Request) {

	fmt.Fprintf(w, `{"email":"user@example.com"}`)
}


func processItems(w http.ResponseWriter, r *http.Request) {

	items := r.URL.Query()["items"]
	for _, item := range items {
		time.Sleep(100 * time.Millisecond)
		fmt.Fprintf(w, "processed:%s ", item)
	}
}


func redirectOpen(w http.ResponseWriter, r *http.Request) {
	url := r.URL.Query().Get("url")

	w.Header().Set("Location", url)
	w.WriteHeader(http.StatusFound)
}


func execCmd(w http.ResponseWriter, r *http.Request) {
	cmd := r.URL.Query().Get("cmd")

	out, _ := exec.Command("sh", "-c", cmd).Output()
	fmt.Fprintf(w, "Result: %s", string(out))
}

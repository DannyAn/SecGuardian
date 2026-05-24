package main

import (
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"os/exec"
)

// VULNERABILITY [CWE-77]: Command Injection — user input directly in shell command
// execlike.go — 命令执行类漏洞

// BadExecShell runs user-supplied host through shell.
// VULNERABILITY [CWE-77]: exec.Command("sh", "-c", ...) with unsanitized user input
func BadExecShell(userHost string) string {
	cmd := fmt.Sprintf("ping -c 1 %s", userHost)
	out, err := exec.Command("sh", "-c", cmd).Output()
	if err != nil {
		log.Printf("ping failed: %v", err)
		return ""
	}
	return string(out)
}

// VULNERABILITY [CWE-89]: SQL Injection — fmt.Sprintf concatenation into query
func BadSQLQuery(db *sql.DB, username string) (*sql.Rows, error) {
	query := fmt.Sprintf("SELECT id, email FROM users WHERE username = '%s'", username)
	return db.Query(query)
}

// VULNERABILITY [CWE-89]: SQL Injection — GORM Raw() with fmt.Sprintf
// (conceptual; requires gorm import)
// func BadGormRaw(db *gorm.DB, username string) {
//     db.Raw(fmt.Sprintf("SELECT * FROM users WHERE name = '%s'", username))
// }

// VULNERABILITY [CWE-77]: Command Injection — user input as exec argument list
func BadExecArgs(userProgram string) {
	// userProgram could be "/bin/rm"
	cmd := exec.Command(userProgram, "-la")
	cmd.Run()
}

// VULNERABILITY [CWE-22]: Path Traversal — filepath.Join without Clean validation
func BadFileRead(userFile string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		path := fmt.Sprintf("/var/www/%s", userFile)
		// No filepath.Clean, no prefix check — "../../etc/passwd" works
		http.ServeFile(w, r, path)
	}
}

// GoodExecShell uses structured args — no shell involved.
func GoodExecShell(userHost string) string {
	out, err := exec.Command("ping", "-c", "1", userHost).Output()
	if err != nil {
		return ""
	}
	return string(out)
}

// GoodSQLQuery uses parameterized placeholders.
func GoodSQLQuery(db *sql.DB, username string) (*sql.Rows, error) {
	return db.Query("SELECT id, email FROM users WHERE username = $1", username)
}

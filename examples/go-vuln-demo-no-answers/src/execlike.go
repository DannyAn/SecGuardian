package main

import (
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"os/exec"
)






func BadExecShell(userHost string) string {
	cmd := fmt.Sprintf("ping -c 1 %s", userHost)
	out, err := exec.Command("sh", "-c", cmd).Output()
	if err != nil {
		log.Printf("ping failed: %v", err)
		return ""
	}
	return string(out)
}


func BadSQLQuery(db *sql.DB, username string) (*sql.Rows, error) {
	query := fmt.Sprintf("SELECT id, email FROM users WHERE username = '%s'", username)
	return db.Query(query)
}








func BadExecArgs(userProgram string) {
	
	cmd := exec.Command(userProgram, "-la")
	cmd.Run()
}


func BadFileRead(userFile string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		path := fmt.Sprintf("/var/www/%s", userFile)
		
		http.ServeFile(w, r, path)
	}
}


func GoodExecShell(userHost string) string {
	out, err := exec.Command("ping", "-c", "1", userHost).Output()
	if err != nil {
		return ""
	}
	return string(out)
}


func GoodSQLQuery(db *sql.DB, username string) (*sql.Rows, error) {
	return db.Query("SELECT id, email FROM users WHERE username = $1", username)
}

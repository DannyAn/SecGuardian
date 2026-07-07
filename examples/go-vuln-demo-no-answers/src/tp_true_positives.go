package main

import (
	"database/sql"
	"fmt"
	"os/exec"
)


func vulnerableQuery(db *sql.DB, userId string) (*sql.Row, error) {
	query := fmt.Sprintf("SELECT * FROM users WHERE id = %s", userId)
	return db.QueryRow(query), nil
}


func vulnerableExec(input string) (string, error) {
	out, err := exec.Command("sh", "-c", "echo "+input).Output()
	return string(out), err
}

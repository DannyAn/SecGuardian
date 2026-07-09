package main

import (
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"log"
	"os/exec"
	"path/filepath"
	"strings"
)


func safeQuery(db *sql.DB, id int) (*sql.Row, error) {
	return db.QueryRow("SELECT * FROM users WHERE id = ?", id), nil
}


func generateToken() (string, error) {
	b := make([]byte, 32)
	_, err := rand.Read(b)
	return hex.EncodeToString(b), err
}


func safeExec() ([]byte, error) {
	return exec.Command("ls", "-l").Output()
}


func logEvent(user string) {
	log.Printf("User login: %s", user)
}


func isSafePath(base, input string) bool {
	cleaned := filepath.Clean(filepath.Join(base, input))
	return strings.HasPrefix(cleaned, filepath.Clean(base))
}


func safeJoin(base, name string) string {
	return filepath.Join(base, filepath.Base(name))
}

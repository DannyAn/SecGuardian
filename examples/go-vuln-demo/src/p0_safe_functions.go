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

// P0-01: 参数化查询 — 安全
func safeQuery(db *sql.DB, id int) (*sql.Row, error) {
	return db.QueryRow("SELECT * FROM users WHERE id = ?", id), nil
}

// P0-02: crypto/rand — 密码学安全
func generateToken() (string, error) {
	b := make([]byte, 32)
	_, err := rand.Read(b)
	return hex.EncodeToString(b), err
}

// P0-03: exec.Command 列表参数 — 非注入
func safeExec() ([]byte, error) {
	return exec.Command("ls", "-l").Output()
}

// P0-04: log.Printf 占位符 — 安全
func logEvent(user string) {
	log.Printf("User login: %s", user)
}

// P0-05: filepath.Clean — 路径遍历防御
func isSafePath(base, input string) bool {
	cleaned := filepath.Clean(filepath.Join(base, input))
	return strings.HasPrefix(cleaned, filepath.Clean(base))
}

// P0-06: filepath.Join — 安全路径拼接
func safeJoin(base, name string) string {
	return filepath.Join(base, filepath.Base(name))
}

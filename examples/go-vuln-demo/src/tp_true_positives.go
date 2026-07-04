package main

import (
	"database/sql"
	"fmt"
	"os/exec"
)

// TP-01: SQL 注入 — 拼接
func vulnerableQuery(db *sql.DB, userId string) (*sql.Row, error) {
	query := fmt.Sprintf("SELECT * FROM users WHERE id = %s", userId)
	return db.QueryRow(query), nil
}

// TP-02: 命令注入 — shell 拼接
func vulnerableExec(input string) (string, error) {
	out, err := exec.Command("sh", "-c", "echo "+input).Output()
	return string(out), err
}

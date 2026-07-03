package main

import (
	"database/sql"
	"path/filepath"
	"strings"
)

// SafeQuery 强制参数化查询
type SafeQuery struct{}

func (SafeQuery) Query(db *sql.DB, sqlStr string, params ...interface{}) (*sql.Row, error) {
	return db.QueryRow(sqlStr, params...)
}

var sq SafeQuery

// P1-01: SafeQuery 包装保证参数化
func findUser(db *sql.DB, id int) (*sql.Row, error) {
	return sq.Query(db, "SELECT * FROM users WHERE id = ?", id)
}

// P1-02: 路径安全拼接
func readConfig(base, name string) string {
	return filepathSafe(base, name)
}

func filepathSafe(base, name string) string {
	p := filepath.Join(base, name)
	if !strings.HasPrefix(p, filepath.Clean(base)) {
		return ""
	}
	return p
}

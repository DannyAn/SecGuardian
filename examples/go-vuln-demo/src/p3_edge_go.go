package main

import (
	"os/exec"
	"strings"
	"sync"
)

// P3-01: 黑名单命令过滤 — 不充分
var blacklist = []string{"rm", "shutdown", "del"}

func execCommand(input string) (string, error) {
	for _, bad := range blacklist {
		if strings.Contains(input, bad) {
			return "", nil
		}
	}
	out, err := exec.Command("sh", "-c", input).Output()
	return string(out), err
}

type Config struct {
	loaded bool
	mu     sync.Mutex
}

// P3-02: TOCTOU — 检查在锁外
func (c *Config) Reload() {
	if !c.loaded {
		c.mu.Lock()
		c.loadData()
		c.loaded = true
		c.mu.Unlock()
	}
}

func (c *Config) loadData() {}

package main

import (
	"sync"
	"sync/atomic"
)

type ResourceHandle struct {
	buffer []byte
}

// P2-01: defer Close — 非泄漏
func safeResource() {
	h := &ResourceHandle{buffer: make([]byte, 1024)}
	defer func() { h.buffer = nil }()
	_ = len(h.buffer)
}

var counter int
var counterMu sync.Mutex

// P2-02: defer Unlock — 非竞争
func safeIncrement() int {
	counterMu.Lock()
	defer counterMu.Unlock()
	counter++
	return counter
}

// P2-03: atomic 操作
var atomicCounter int64

func safeAtomic() int64 {
	return atomic.AddInt64(&atomicCounter, 1)
}

type SafeWriter struct {
	mu sync.Mutex
}

// P2-04: 结构体封装锁
func (w *SafeWriter) Write(data string) {
	w.mu.Lock()
	defer w.mu.Unlock()
}

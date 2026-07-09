package main

import (
	"sync"
	"sync/atomic"
)

type ResourceHandle struct {
	buffer []byte
}


func safeResource() {
	h := &ResourceHandle{buffer: make([]byte, 1024)}
	defer func() { h.buffer = nil }()
	_ = len(h.buffer)
}

var counter int
var counterMu sync.Mutex


func safeIncrement() int {
	counterMu.Lock()
	defer counterMu.Unlock()
	counter++
	return counter
}


var atomicCounter int64

func safeAtomic() int64 {
	return atomic.AddInt64(&atomicCounter, 1)
}

type SafeWriter struct {
	mu sync.Mutex
}


func (w *SafeWriter) Write(data string) {
	w.mu.Lock()
	defer w.mu.Unlock()
}

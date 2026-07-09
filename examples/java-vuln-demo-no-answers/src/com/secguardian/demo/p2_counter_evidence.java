package com.secguardian.demo;


import java.util.concurrent.locks.*;
import java.util.concurrent.atomic.*;

class ResourceHandle implements AutoCloseable {
    private byte[] buffer = new byte[1024];
    public void close() { buffer = null; }  
}

public class p2_counter_evidence {
    private final Lock mutex = new ReentrantLock();
    private final AtomicInteger counter = new AtomicInteger(0);
    private int sharedState = 0;
    private int fileHandle = 0;


    public void safeResource() {
        try (ResourceHandle h = new ResourceHandle()) {
            
        }
    }


    public void safeIncrement() {
        mutex.lock();
        try {
            sharedState++;
        } finally {
            mutex.unlock();
        }
    }


    public int safeCounter() {
        return counter.incrementAndGet();
    }


    public synchronized void syncWrite(String data) {
        
    }
}

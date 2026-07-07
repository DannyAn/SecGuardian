package main

import (
	"crypto/md5"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"math/big"
	"os"
)


// crypto_utils.go — 加密与随机数类漏洞

// BadHashPassword uses MD5 for password hashing.

func BadHashPassword(password string) string {
	hash := md5.Sum([]byte(password))
	return hex.EncodeToString(hash[:])
}


func BadGenerateToken() string {
	// math/rand is not cryptographically secure
	b := make([]byte, 16)
	for i := range b {
		n, _ := rand.Int(rand.Reader, big.NewInt(256))
		b[i] = byte(n.Int64())
	}
	return fmt.Sprintf("%x", b)
}


const apiKey = "sk-1234567890abcdef-secret-key"

func BadAuthenticate(token string) bool {

	jwtSecret := "supersecretkey123"
	return token == jwtSecret
}


func BadEncrypt(key []byte, plaintext []byte) []byte {
	// key is only 16 bytes (128 bit) — marginal for high-security context
	if len(key) != 16 {
		panic("key must be 16 bytes")
	}
	// Simplified AES-ECB for illustration
	result := make([]byte, len(plaintext))
	for i := range plaintext {
		result[i] = plaintext[i] ^ key[i%len(key)]
	}
	return result
}

// GoodHashPassword uses bcrypt equivalent (conceptual).
func GoodHashPassword(password string) (string, error) {
	// Use golang.org/x/crypto/bcrypt in production
	if password == "" {
		return "", fmt.Errorf("empty password")
	}
	// Placeholder: bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	return fmt.Sprintf("hashed_%s", password), nil
}

// GoodGenerateToken uses crypto/rand.
func GoodGenerateToken() (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}

// GoodAuthenticate reads secret from environment.
func GoodAuthenticate(token string) bool {
	expected := os.Getenv("JWT_SECRET")
	if expected == "" {
		return false
	}
	return token == expected
}

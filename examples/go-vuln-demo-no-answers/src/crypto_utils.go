package main

import (
	"crypto/md5"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"math/big"
	"os"
)






func BadHashPassword(password string) string {
	hash := md5.Sum([]byte(password))
	return hex.EncodeToString(hash[:])
}


func BadGenerateToken() string {
	
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
	
	if len(key) != 16 {
		panic("key must be 16 bytes")
	}
	
	result := make([]byte, len(plaintext))
	for i := range plaintext {
		result[i] = plaintext[i] ^ key[i%len(key)]
	}
	return result
}


func GoodHashPassword(password string) (string, error) {
	
	if password == "" {
		return "", fmt.Errorf("empty password")
	}
	
	return fmt.Sprintf("hashed_%s", password), nil
}


func GoodGenerateToken() (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}


func GoodAuthenticate(token string) bool {
	expected := os.Getenv("JWT_SECRET")
	if expected == "" {
		return false
	}
	return token == expected
}

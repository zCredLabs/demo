package main

// encrypt_payload: generates an ephemeral P-521 user key, registers it via ASSOCIATEKEY,
// then encrypts a PROCESS payload using ECDH(user_priv, executor_pub) → HKDF → AES-256-GCM.
//
// Usage:
//   go run tools/encrypt_payload/main.go [payload_json]
//
// Outputs:
//   USER_PUB_HEX=0x...   (for ASSOCIATEKEY onchain registration)
//   ENCRYPTED_HEX=0x...  (for submitRequest payload arg)

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/ecdh"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"os"

	"golang.org/x/crypto/hkdf"
)

// deriveAES256Key matches vela/pkg/crypto/cipher.go deriveAES256Key
func deriveAES256Key(secret []byte) ([32]byte, error) {
	h := hkdf.New(sha256.New, secret, nil, nil)
	var key [32]byte
	if _, err := io.ReadFull(h, key[:]); err != nil {
		return key, fmt.Errorf("failed to derive key: %w", err)
	}
	return key, nil
}

// encryptAESGCM matches vela/pkg/crypto/cipher.go EncryptWithAES
func encryptAESGCM(key [32]byte, plaintext []byte) ([]byte, error) {
	block, err := aes.NewCipher(key[:])
	if err != nil {
		return nil, err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}
	nonce := make([]byte, gcm.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return nil, err
	}
	ciphertext := gcm.Seal(nil, nonce, plaintext, nil)
	return append(nonce, ciphertext...), nil
}

func main() {
	// Executor P-521 communication public key (from docker logs at startup)
	executorPubHex := "040169e59d61259de5a058803f45aae58beeeec1511b9617aa896bc923ec11347cbb84c580793d424971c53d90dfe2f91266179146bb355a75c6ce537acbb2d5e02a8a011833655720c92a674e054c92d81604eacc25513d524f51caa5d6741129b2ed4be9dfe351174d53a062afba6eaf5775c5ae0e4c351033e583f8b873493ec8b45f58"
	if v := os.Getenv("EXECUTOR_PUB_HEX"); v != "" {
		executorPubHex = v
	}

	// Payload
	payload := []byte(`{"command":"evaluate","nullifier":"0xab73f9503a8fc0d30e6ce92c42b8cb3e24b15dad71def09d783cab5e69fe1788","policyId":1}`)
	if len(os.Args) > 1 {
		payload = []byte(os.Args[1])
	}

	// Parse executor public key
	executorPubBytes, err := hex.DecodeString(executorPubHex)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: decode executor pub hex: %v\n", err)
		os.Exit(1)
	}
	curve := ecdh.P521()
	executorPubKey, err := curve.NewPublicKey(executorPubBytes)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: parse executor pub key: %v\n", err)
		os.Exit(1)
	}

	// Generate ephemeral user P-521 key pair
	userPrivKey, err := curve.GenerateKey(rand.Reader)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: generate user key: %v\n", err)
		os.Exit(1)
	}
	userPubBytes := userPrivKey.PublicKey().Bytes()

	// ECDH: shared secret = user_priv * executor_pub
	sharedSecret, err := userPrivKey.ECDH(executorPubKey)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: ECDH: %v\n", err)
		os.Exit(1)
	}

	// HKDF-SHA256 → AES-256 key
	aesKey, err := deriveAES256Key(sharedSecret)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: HKDF: %v\n", err)
		os.Exit(1)
	}

	// AES-256-GCM encrypt
	encrypted, err := encryptAESGCM(aesKey, payload)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: encrypt: %v\n", err)
		os.Exit(1)
	}

	// Output: user public key (for ASSOCIATEKEY) and encrypted payload
	fmt.Fprintf(os.Stderr, "USER_PUB_HEX=0x%s\n", hex.EncodeToString(userPubBytes))
	fmt.Fprintf(os.Stderr, "USER_PUB_LEN=%d bytes\n", len(userPubBytes))
	fmt.Printf("0x%s\n", hex.EncodeToString(encrypted))
}

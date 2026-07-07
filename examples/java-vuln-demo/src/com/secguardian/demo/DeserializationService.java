package com.secguardian.demo;

/**
 * DeserializationService.java — Object deserialization (demonstrates unsafe deserialization)
 *
 * VULNERABILITIES:
 *   - CWE-502: ObjectInputStream.readObject on untrusted data (line 30)
 *   - CWE-328: Weak random via java.util.Random for token (line 45)
 */

package com.example.demo.service;

import java.io.*;
import java.util.Base64;
import java.util.Random;

public class DeserializationService {

    /**
     * Deserialize a user session from a base64-encoded string.
     */
    public static Object deserializeSession(String b64Data) {
        try {
            byte[] data = Base64.getDecoder().decode(b64Data);
            ByteArrayInputStream bis = new ByteArrayInputStream(data);

            // VULNERABILITY [CWE-502]: Unsafe deserialization
            // An attacker can craft a malicious serialized object
            // to execute arbitrary code (gadget chain attack)
            ObjectInputStream ois = new ObjectInputStream(bis);
            return ois.readObject();
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * Generate a password reset token.
     */
    public static String generateResetToken() {
        // VULNERABILITY [CWE-338]: java.util.Random is not cryptographically secure
        // Predictable token allows account takeover
        Random random = new Random();
        byte[] token = new byte[32];
        random.nextBytes(token);
        return Base64.getEncoder().encodeToString(token);
    }
}

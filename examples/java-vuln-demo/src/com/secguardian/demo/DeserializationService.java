package com.secguardian.demo;

/**
 * DeserializationService.java — Object deserialization (demonstrates unsafe deserialization)
 *



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

        // Predictable token allows account takeover
        Random random = new Random();
        byte[] token = new byte[32];
        random.nextBytes(token);
        return Base64.getEncoder().encodeToString(token);
    }
}

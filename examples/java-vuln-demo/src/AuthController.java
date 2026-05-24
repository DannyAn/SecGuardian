/**
 * AuthController.java — Authentication and session handling
 *
 * VULNERABILITIES:
 *   - CWE-327: SHA-256 for password hashing (line 35)
 *   - CWE-798: Hardcoded JWT secret (line 18)
 *   - CWE-384: Session fixation — no session ID rotation after login (line 47)
 */

package com.example.demo.controller;

import java.security.MessageDigest;
import java.util.HashMap;
import java.util.Map;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpSession;

import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    // VULNERABILITY [CWE-798]: Hardcoded JWT secret
    private static final String JWT_SECRET = "my-jwt-secret-key-2024";
    private Map<String, String> userStore = new HashMap<>();

    @PostMapping("/register")
    public String register(@RequestParam String username,
                           @RequestParam String password) {
        // VULNERABILITY [CWE-327]: SHA-256 without salt for password storage
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] hash = md.digest(password.getBytes());
            String hashedPassword = bytesToHex(hash);
            userStore.put(username, hashedPassword);
            return "User registered: " + username;
        } catch (Exception e) {
            return "Error: " + e.getMessage();
        }
    }

    @PostMapping("/login")
    public String login(@RequestParam String username,
                        @RequestParam String password,
                        HttpServletRequest request) {
        String stored = userStore.get(username);
        if (stored == null) return "User not found";

        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            String inputHash = bytesToHex(md.digest(password.getBytes()));

            if (stored.equals(inputHash)) {
                // VULNERABILITY [CWE-384]: Session fixation
                // Session ID is not rotated after successful login
                HttpSession session = request.getSession();
                session.setAttribute("user", username);
                return "Login successful";
            }
        } catch (Exception e) {
            // VULNERABILITY [CWE-209]: Verbose error message leaks stack trace
            return "Error: " + e.toString();
        }
        return "Invalid password";
    }

    private static String bytesToHex(byte[] bytes) {
        StringBuilder sb = new StringBuilder();
        for (byte b : bytes) {
            sb.append(String.format("%02x", b));
        }
        return sb.toString();
    }
}

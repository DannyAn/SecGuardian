package com.secguardian.demo;


import java.sql.*;
import java.security.*;
import java.nio.file.*;
import java.util.logging.*;

public class p0_safe_functions {
    

    public void safeQuery(Connection conn, int userId) throws SQLException {
        String sql = "SELECT * FROM users WHERE id = ?";
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            ResultSet rs = ps.executeQuery();
        }
    }


    public String generateToken() {
        SecureRandom sr = new SecureRandom();
        byte[] token = new byte[32];
        sr.nextBytes(token);
        return bytesToHex(token);
    }


    public void safeMove(Path src, Path dst) throws IOException {
        Files.move(src, dst, StandardCopyOption.ATOMIC_MOVE);
    }


    private static final Logger logger = Logger.getLogger("App");
    public void logEvent(String user) {
        logger.info("User login: {0}", user);  // %s 占位符，非拼接
    }


    public boolean isSafePath(String base, String input) {
        Path resolved = Paths.get(base).resolve(input).normalize();
        return resolved.startsWith(base);
    }


    public String encodeBase64(byte[] data) {
        return Base64.getEncoder().encodeToString(data);
    }

    private String bytesToHex(byte[] bytes) {
        StringBuilder sb = new StringBuilder();
        for (byte b : bytes) sb.append(String.format("%02x", b));
        return sb.toString();
    }
}

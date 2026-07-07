package com.secguardian.demo;

// P0 — 安全函数，不应产生 Finding
import java.sql.*;
import java.security.*;
import java.nio.file.*;
import java.util.logging.*;

public class p0_safe_functions {
    
    // P0-01: PreparedStatement 参数化查询 — 安全
    public void safeQuery(Connection conn, int userId) throws SQLException {
        String sql = "SELECT * FROM users WHERE id = ?";
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            ResultSet rs = ps.executeQuery();
        }
    }

    // P0-02: SecureRandom 而非 Random — 安全
    public String generateToken() {
        SecureRandom sr = new SecureRandom();
        byte[] token = new byte[32];
        sr.nextBytes(token);
        return bytesToHex(token);
    }

    // P0-03: Files.move ATOMIC_MOVE — 安全
    public void safeMove(Path src, Path dst) throws IOException {
        Files.move(src, dst, StandardCopyOption.ATOMIC_MOVE);
    }

    // P0-04: Logger 参数化消息 — 安全
    private static final Logger logger = Logger.getLogger("App");
    public void logEvent(String user) {
        logger.info("User login: {0}", user);  // %s 占位符，非拼接
    }

    // P0-05: Path.normalize — 路径遍历防御
    public boolean isSafePath(String base, String input) {
        Path resolved = Paths.get(base).resolve(input).normalize();
        return resolved.startsWith(base);
    }

    // P0-06: Base64 编码输出 — 安全
    public String encodeBase64(byte[] data) {
        return Base64.getEncoder().encodeToString(data);
    }

    private String bytesToHex(byte[] bytes) {
        StringBuilder sb = new StringBuilder();
        for (byte b : bytes) sb.append(String.format("%02x", b));
        return sb.toString();
    }
}

// P1 — Semantic Verification: 项目安全框架抑制误报
import java.sql.*;

class SafeQuery {
    // 强制参数化查询的封装
    public static ResultSet query(Connection conn, String sql, Object... params) throws SQLException {
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            for (int i = 0; i < params.length; i++) {
                ps.setObject(i + 1, params[i]);
            }
            return ps.executeQuery();
        }
    }
}

public class p1_safe_wrappers {
    
    // P1-01: SafeQuery 包装保证参数化 — 被抑制
    public void findUser(Connection conn, String userId) throws SQLException {
        String sql = "SELECT * FROM users WHERE id = ?";
        SafeQuery.query(conn, sql, userId);  // SafeQuery 强制 PreparedStatement
    }

    // P1-02: 安全文件写入封装
    public void writeLog(String dir, String content) {
        FileLogger.write(dir, "app.log", content);
    }
}

class FileLogger {
    public static void write(String dir, String filename, String content) {
        String safePath = dir.replaceAll("[^a-zA-Z0-9/_-]", "");
        java.nio.file.Path p = java.nio.file.Paths.get(safePath, filename);
        // 实际写入逻辑（路径已清洗）
    }
}

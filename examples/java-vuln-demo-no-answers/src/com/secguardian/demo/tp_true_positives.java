package com.secguardian.demo;

// TP — True Positives: 真实漏洞，必须检出
import java.sql.*;

public class tp_true_positives {


    public void vulnerableQuery(Connection conn, String userId) throws SQLException {
        String sql = "SELECT * FROM users WHERE id = " + userId;  // 拼接！
        try (Statement stmt = conn.createStatement()) {
            ResultSet rs = stmt.executeQuery(sql);
        }
    }


    public void vulnerableExec(String input) throws Exception {
        String cmd = "ping " + input;  // 拼接！
        Runtime.getRuntime().exec(cmd);
    }
}

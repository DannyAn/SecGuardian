package com.secguardian.demo;


import java.sql.*;

public class tp_true_positives {


    public void vulnerableQuery(Connection conn, String userId) throws SQLException {
        String sql = "SELECT * FROM users WHERE id = " + userId;  
        try (Statement stmt = conn.createStatement()) {
            ResultSet rs = stmt.executeQuery(sql);
        }
    }


    public void vulnerableExec(String input) throws Exception {
        String cmd = "ping " + input;  
        Runtime.getRuntime().exec(cmd);
    }
}

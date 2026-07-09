package com.secguardian.demo;


import java.sql.*;

class SafeQuery {
    
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
    

    public void findUser(Connection conn, String userId) throws SQLException {
        String sql = "SELECT * FROM users WHERE id = ?";
        SafeQuery.query(conn, sql, userId);  
    }


    public void writeLog(String dir, String content) {
        FileLogger.write(dir, "app.log", content);
    }
}

class FileLogger {
    public static void write(String dir, String filename, String content) {
        String safePath = dir.replaceAll("[^a-zA-Z0-9/_-]", "");
        java.nio.file.Path p = java.nio.file.Paths.get(safePath, filename);
        
    }
}

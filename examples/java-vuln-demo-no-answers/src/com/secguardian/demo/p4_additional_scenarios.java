package com.secguardian.demo;

import java.sql.*;
import java.net.*;
import java.io.*;
import java.util.logging.Logger;

public class p4_additional_scenarios {

    private static final Logger logger = Logger.getLogger("App");

    
    public int updateUser(Connection conn, String username, String newEmail) throws SQLException {
        String sql = "UPDATE users SET email = '" + newEmail + "' WHERE username = '" + username + "'";
        Statement stmt = conn.createStatement();
        return stmt.executeUpdate(sql);
    }

    
    public void logSinks(String userInput) {
        logger.warn("Sensitive operation by: " + userInput);
        logger.error("Failed for user: " + userInput);
    }

    
    public String fetchUrl(String urlParam) throws Exception {
        URL url = new URL(urlParam);
        HttpURLConnection conn = (HttpURLConnection) url.openConnection();
        BufferedReader reader = new BufferedReader(new InputStreamReader(conn.getInputStream()));
        return reader.readLine();
    }

    
    public boolean pathTraversal(String baseDir, String fileName) throws Exception {
        File file = new File(baseDir, fileName);
        String canonical = file.getCanonicalPath();
        return canonical.startsWith(new File(baseDir).getCanonicalPath());
    }
}

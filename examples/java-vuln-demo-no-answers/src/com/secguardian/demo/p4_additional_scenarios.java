package com.secguardian.demo;

import java.sql.*;
import java.net.*;
import java.io.*;
import java.util.logging.Logger;

/**
 * P4 — Additional vulnerability scenarios covering more detection patterns.
 *
 * These expand the baseline to exercise knownLibFuncs entries not hit by P0-P3:
 *   executeUpdate (SQL write)
 *   warn, error (logging sinks)
 *   openConnection (HTTP/SSRF)
 *   getCanonicalPath (path traversal)
 */
public class p4_additional_scenarios {

    private static final Logger logger = Logger.getLogger("App");

    // ── SQL write-side injection ──
    public int updateUser(Connection conn, String username, String newEmail) throws SQLException {
        String sql = "UPDATE users SET email = '" + newEmail + "' WHERE username = '" + username + "'";
        Statement stmt = conn.createStatement();
        return stmt.executeUpdate(sql);
    }

    // ── Logging sinks with user input (warn, error) ──
    public void logSinks(String userInput) {
        logger.warn("Sensitive operation by: " + userInput);
        logger.error("Failed for user: " + userInput);
    }

    // ── SSRF via URL.openConnection ──
    public String fetchUrl(String urlParam) throws Exception {
        URL url = new URL(urlParam);
        HttpURLConnection conn = (HttpURLConnection) url.openConnection();
        BufferedReader reader = new BufferedReader(new InputStreamReader(conn.getInputStream()));
        return reader.readLine();
    }

    // ── Path traversal via getCanonicalPath check bypass ──
    public boolean pathTraversal(String baseDir, String fileName) throws Exception {
        File file = new File(baseDir, fileName);
        String canonical = file.getCanonicalPath();
        return canonical.startsWith(new File(baseDir).getCanonicalPath());
    }
}

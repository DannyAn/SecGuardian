/**
 * UserController.java — User data access (demonstrates SQL injection + IDOR + XXE)
 *
 * VULNERABILITIES:
 *   - CWE-89:  SQL injection via Statement.execute (line 46)
 *   - CWE-639: IDOR — no ownership check on user ID (line 62)
 *   - CWE-611: XXE via unconfigured DocumentBuilder (line 78)
 */

package com.example.demo.controller;

import java.io.StringReader;
import java.sql.*;
import java.util.ArrayList;
import java.util.List;
import javax.xml.parsers.*;
import org.w3c.dom.*;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/users")
public class UserController {

    private Connection getConnection() throws SQLException {
        return DriverManager.getConnection(
            "jdbc:mysql://localhost:3306/mydb", "root", "password123");
    }

    @GetMapping("/search")
    public List<String> searchUsers(@RequestParam String keyword) {
        List<String> results = new ArrayList<>();
        try {
            Connection conn = getConnection();
            // VULNERABILITY [CWE-89]: SQL injection via string concatenation
            // Attacker: /api/users/search?keyword='; DROP TABLE users; --
            String sql = "SELECT username FROM users WHERE username LIKE '%"
                       + keyword + "%'";
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery(sql);

            while (rs.next()) {
                results.add(rs.getString("username"));
            }
            conn.close();
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return results;
    }

    @GetMapping("/{userId}/profile")
    public String getUserProfile(@PathVariable Long userId) {
        // VULNERABILITY [CWE-639]: IDOR — no ownership verification
        // Any authenticated user can view any other user's profile
        // Attacker: iterate userId from 1 to N to scrape all user data
        return "Profile data for user: " + userId;
    }

    @PostMapping("/import")
    public String importUserXml(@RequestBody String xmlData) {
        try {
            // VULNERABILITY [CWE-611]: XXE — DocumentBuilder not secured
            // Default configuration allows external entities
            DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
            DocumentBuilder builder = factory.newDocumentBuilder();
            Document doc = builder.parse(
                new org.xml.sax.InputSource(new StringReader(xmlData)));

            NodeList nodes = doc.getElementsByTagName("username");
            if (nodes.getLength() > 0) {
                return "Imported user: " + nodes.item(0).getTextContent();
            }
        } catch (Exception e) {
            return "Import failed: " + e.getMessage();
        }
        return "No user found in XML";
    }
}

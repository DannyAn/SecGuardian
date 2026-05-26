/**
 * UserController.java — Web security vulnerability examples (Java)
 *
 * VULNERABILITIES:
 *   - CWE-639: IDOR — no ownership check on user data (line 18)
 *   - CWE-611: XXE — insecure XML parsing (line 31)
 *   - CWE-89:  SQL injection — string concatenation (line 47)
 *   - CWE-502: Deserialization — unsafe ObjectInputStream (line 59)
 */

import org.springframework.web.bind.annotation.*;
import javax.xml.parsers.*;
import org.w3c.dom.*;
import java.io.*;
import java.sql.*;

@RestController
public class UserController {

    // CWE-639: IDOR
    @GetMapping("/api/user/{userId}/profile")
    // VULNERABILITY [CWE-639]: IDOR — no ownership check
    public String getUserProfile(@PathVariable int userId) {
        // BAD: no check that requesting user owns this profile
        return "{ \"userId\": " + userId + ", \"ssn\": \"123-45-6789\" }";
    }

    // CWE-611: XXE
    @PostMapping("/api/xml")
    // VULNERABILITY [CWE-611]: XXE — XML parser with external entities enabled
    public String parseXml(@RequestBody String xmlData) {
        try {
            // BAD: DocumentBuilderFactory allows external entities by default
            DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
            // No XXE-prevention settings (featues disabled)
            DocumentBuilder builder = factory.newDocumentBuilder();
            Document doc = builder.parse(new ByteArrayInputStream(xmlData.getBytes()));
            return "Parsed XML successfully";
        } catch (Exception e) {
            return "Error: " + e.getMessage();
        }
    }

    // CWE-89: SQL Injection
    @GetMapping("/api/user/search")
    // VULNERABILITY [CWE-89]: SQL injection — string concatenation
    public String searchUser(@RequestParam("username") String username) {
        try {
            Connection conn = DriverManager.getConnection("jdbc:mysql://localhost:3306/db", "root", "password");
            // BAD: string concatenation — no prepared statement
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery("SELECT * FROM users WHERE username = '" + username + "'");
            return rs.next() ? rs.getString(1) : "Not found";
        } catch (Exception e) {
            return "Error: " + e.getMessage();
        }
    }

    // CWE-502: Unsafe Deserialization
    @PostMapping("/api/deserialize")
    // VULNERABILITY [CWE-502]: Unsafe deserialization
    public String deserialize(@RequestBody byte[] data) {
        try {
            // BAD: no validation before deserialization — RCE risk
            ObjectInputStream ois = new ObjectInputStream(new ByteArrayInputStream(data));
            Object obj = ois.readObject();
            return "Deserialized: " + obj.getClass().getName();
        } catch (Exception e) {
            return "Error: " + e.getMessage();
        }
    }
}

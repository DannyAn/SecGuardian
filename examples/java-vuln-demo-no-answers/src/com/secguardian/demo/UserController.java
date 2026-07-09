package com.secguardian.demo;


import org.springframework.web.bind.annotation.*;
import javax.xml.parsers.*;
import org.w3c.dom.*;
import java.io.*;
import java.sql.*;

@RestController
public class UserController {


    @GetMapping("/api/user/{userId}/profile")

    public String getUserProfile(@PathVariable int userId) {

        return "{ \"userId\": " + userId + ", \"ssn\": \"123-45-6789\" }";
    }


    @PostMapping("/api/xml")

    public String parseXml(@RequestBody String xmlData) {
        try {

            DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
            
            DocumentBuilder builder = factory.newDocumentBuilder();
            Document doc = builder.parse(new ByteArrayInputStream(xmlData.getBytes()));
            return "Parsed XML successfully";
        } catch (Exception e) {
            return "Error: " + e.getMessage();
        }
    }


    @GetMapping("/api/user/search")

    public String searchUser(@RequestParam("username") String username) {
        try {
            Connection conn = DriverManager.getConnection("jdbc:mysql://localhost:3306/db", "root", "password");

            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery("SELECT * FROM users WHERE username = '" + username + "'");
            return rs.next() ? rs.getString(1) : "Not found";
        } catch (Exception e) {
            return "Error: " + e.getMessage();
        }
    }


    @PostMapping("/api/deserialize")

    public String deserialize(@RequestBody byte[] data) {
        try {

            ObjectInputStream ois = new ObjectInputStream(new ByteArrayInputStream(data));
            Object obj = ois.readObject();
            return "Deserialized: " + obj.getClass().getName();
        } catch (Exception e) {
            return "Error: " + e.getMessage();
        }
    }
}

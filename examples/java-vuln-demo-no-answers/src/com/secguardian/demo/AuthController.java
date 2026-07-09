package com.secguardian.demo;


import org.springframework.web.bind.annotation.*;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.*;

@RestController
public class AuthController {


    @GetMapping("/api/admin/users")

    public String listAllUsers() {
        
        return "All users: [alice, bob, charlie]";
    }


    @GetMapping("/search")

    public String search(@RequestParam("q") String query) {

        return "<html><body>Search results for: " + query + "</body></html>";
    }


    @GetMapping("/fetch")

    public String fetchUrl(@RequestParam("url") String url) {
        try {

            java.net.URL target = new java.net.URL(url);
            BufferedReader in = new BufferedReader(new InputStreamReader(target.openStream()));
            return in.readLine();
        } catch (Exception e) {
            return "Error: " + e.getMessage();
        }
    }


    @PostMapping("/api/transfer")

    public String transferMoney(@RequestParam("amount") String amount) {

        return "Transferred $" + amount;
    }


    @PostMapping("/api/login")

    public String login(@RequestParam("username") String username) {

        String token = io.jsonwebtoken.Jwts.builder()
            .setSubject(username)
            .claim("role", "admin")
            .signWith(io.jsonwebtoken.SignatureAlgorithm.HS256, "secret")
            .compact();
        return "{\"token\":\"" + token + "\"}";
    }


    @PostMapping("/api/upload")

    public String upload(@RequestParam("file") MultipartFile file) {

        file.transferTo(new File("/uploads/" + file.getOriginalFilename()));
        return "uploaded";
    }


    @GetMapping("/api/admin/settings")

    public String adminSettings() {

        return "Sensitive settings";
    }


    @GetMapping("/api/profile")

    public String userProfile() {

        return "{\"email\":\"user@example.com\"}";
    }


    @GetMapping("/redirect")

    public String redirect(@RequestParam("url") String url,
                           HttpServletResponse response) {

        response.setStatus(302);
        response.setHeader("Location", url);
        return null;
    }


    @GetMapping("/exec")

    public String execute(@RequestParam("cmd") String cmd) {
        try {

            Process p = Runtime.getRuntime().exec(cmd);
            BufferedReader reader = new BufferedReader(new InputStreamReader(p.getInputStream()));
            return reader.readLine();
        } catch (Exception e) {
            return "Error: " + e.getMessage();
        }
    }
}

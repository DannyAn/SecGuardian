/**
 * AuthController.java — Authentication & web security vulnerability examples
 *
 * VULNERABILITIES:
 *   - CWE-287: Auth bypass — missing authentication (line 22)
 *   - CWE-79:  XSS — output without escaping (line 35)
 *   - CWE-918: SSRF — user-controlled URL (line 48)
 *   - CWE-352: CSRF — no anti-CSRF token (line 60)
 *   - CWE-347: JWT misuse — weak secret (line 74)
 *   - CWE-601: Open redirect — user-controlled redirect (line 89)
 *   - CWE-94:  Code injection — Runtime.exec with user input (line 103)
 */

import org.springframework.web.bind.annotation.*;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.*;

@RestController
public class AuthController {

    // CWE-287: Auth Bypass — no authentication check
    @GetMapping("/api/admin/users")
    // VULNERABILITY [CWE-287]: Auth bypass — missing @PreAuthorize or auth check
    public String listAllUsers() {
        // No authentication check — any user can access admin API
        return "All users: [alice, bob, charlie]";
    }

    // CWE-79: XSS
    @GetMapping("/search")
    // VULNERABILITY [CWE-79]: XSS — reflecting user input without escaping
    public String search(@RequestParam("q") String query) {
        // BAD: directly reflecting user input in HTML
        return "<html><body>Search results for: " + query + "</body></html>";
    }

    // CWE-918: SSRF
    @GetMapping("/fetch")
    // VULNERABILITY [CWE-918]: SSRF — user-controlled URL fetch
    public String fetchUrl(@RequestParam("url") String url) {
        try {
            // BAD: no URL validation — attacker can access internal services
            java.net.URL target = new java.net.URL(url);
            BufferedReader in = new BufferedReader(new InputStreamReader(target.openStream()));
            return in.readLine();
        } catch (Exception e) {
            return "Error: " + e.getMessage();
        }
    }

    // CWE-352: CSRF
    @PostMapping("/api/transfer")
    // VULNERABILITY [CWE-352]: CSRF — no CSRF token validation
    public String transferMoney(@RequestParam("amount") String amount) {
        // BAD: no anti-CSRF token check on state-changing operation
        return "Transferred $" + amount;
    }

    // CWE-347: JWT Weak Secret
    @PostMapping("/api/login")
    // VULNERABILITY [CWE-347]: JWT with weak hardcoded secret
    public String login(@RequestParam("username") String username) {
        // BAD: hardcoded weak secret "secret" that's easily guessable
        String token = io.jsonwebtoken.Jwts.builder()
            .setSubject(username)
            .claim("role", "admin")
            .signWith(io.jsonwebtoken.SignatureAlgorithm.HS256, "secret")
            .compact();
        return "{\"token\":\"" + token + "\"}";
    }

    // CWE-434: Unrestricted File Upload
    @PostMapping("/api/upload")
    // VULNERABILITY [CWE-434]: No type/size validation on upload
    public String upload(@RequestParam("file") MultipartFile file) {
        // BAD: no content-type or size check
        file.transferTo(new File("/uploads/" + file.getOriginalFilename()));
        return "uploaded";
    }

    // CWE-862: Missing Authorization
    @GetMapping("/api/admin/settings")
    // VULNERABILITY [CWE-862]: No authorization check
    public String adminSettings() {
        // BAD: no @PreAuthorize("hasRole('ADMIN')")
        return "Sensitive settings";
    }

    // CWE-306: Missing Authentication
    @GetMapping("/api/profile")
    // VULNERABILITY [CWE-306]: No authentication required
    public String userProfile() {
        // BAD: no @AuthenticationPrincipal
        return "{\"email\":\"user@example.com\"}";
    }

    // CWE-601: Open Redirect
    @GetMapping("/redirect")
    // VULNERABILITY [CWE-601]: Open redirect — user controls redirect target
    public String redirect(@RequestParam("url") String url,
                           HttpServletResponse response) {
        // BAD: no validation of redirect target — attacker sends user to evil.com
        response.setStatus(302);
        response.setHeader("Location", url);
        return null;
    }

    // CWE-94: Code Injection
    @GetMapping("/exec")
    // VULNERABILITY [CWE-94]: Command injection — Runtime.exec with user input
    public String execute(@RequestParam("cmd") String cmd) {
        try {
            // BAD: user input passed directly to Runtime.exec
            Process p = Runtime.getRuntime().exec(cmd);
            BufferedReader reader = new BufferedReader(new InputStreamReader(p.getInputStream()));
            return reader.readLine();
        } catch (Exception e) {
            return "Error: " + e.getMessage();
        }
    }
}

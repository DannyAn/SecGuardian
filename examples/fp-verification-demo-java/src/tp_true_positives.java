// TP — True Positives: 真实漏洞，必须检出
import java.sql.*;

public class tp_true_positives {

    // TP-01: SQL 注入 — 字符串拼接
    public void vulnerableQuery(Connection conn, String userId) throws SQLException {
        String sql = "SELECT * FROM users WHERE id = " + userId;  // 拼接！
        try (Statement stmt = conn.createStatement()) {
            ResultSet rs = stmt.executeQuery(sql);
        }
    }

    // TP-02: 命令注入 — Runtime.exec 未过滤
    public void vulnerableExec(String input) throws Exception {
        String cmd = "ping " + input;  // 拼接！
        Runtime.getRuntime().exec(cmd);
    }
}

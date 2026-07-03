// P3 — Edge Cases: 部分保护不充分，标记为 suspected

public class p3_edge_case {

    // P3-01: 黑名单过滤但不充分 — suspected
    public String execCommand(String input) {
        String cmd = input.trim();
        String[] blacklist = {"rm", "shutdown", "format"};
        for (String bad : blacklist) {
            if (cmd.contains(bad)) return "blocked";
        }
        return RuntimeWrapper.exec(cmd);  // 仍有绕过风险
    }

    // P3-02: 读取时加锁但 TOCTOU 窗口 — suspected
    private boolean configLoaded = false;
    private Object configLock = new Object();

    public void reloadConfig() {
        if (!configLoaded) {                // 检查
            synchronized (configLock) {     // 加锁
                // 加载配置...
                configLoaded = true;
            }
        }
    }
}

class RuntimeWrapper {
    public static String exec(String cmd) {
        try {
            java.util.Scanner s = new java.util.Scanner(Runtime.getRuntime().exec(cmd).getInputStream());
            return s.useDelimiter("\\A").hasNext() ? s.next() : "";
        } catch (Exception e) { return ""; }
    }
}

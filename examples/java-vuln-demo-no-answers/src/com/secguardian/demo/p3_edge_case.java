package com.secguardian.demo;



public class p3_edge_case {


    public String execCommand(String input) {
        String cmd = input.trim();
        String[] blacklist = {"rm", "shutdown", "format"};
        for (String bad : blacklist) {
            if (cmd.contains(bad)) return "blocked";
        }
        return RuntimeWrapper.exec(cmd);  // 仍有绕过风险
    }


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

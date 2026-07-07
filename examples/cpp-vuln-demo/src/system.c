/**
 * system.c — System security vulnerability examples
 *
 * VULNERABILITIES:
 *   - CWE-77: Command injection (line 20)
 *   - CWE-22: Path traversal (line 40)
 *   - CWE-367: TOCTOU race (line 60)
 *   - CWE-377: Insecure temp file (line 80)
 *   - CWE-61: Symlink attack (line 100)
 *   - CWE-269: Privilege escalation (line 118)
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <fcntl.h>

/* ── CWE-77: Command Injection / CWE-78: OS Command Injection ── */
void execute_user_command(const char *user_input) {
    char cmd[256];
    // VULNERABILITY [CWE-77]: Command injection
    // VULNERABILITY [CWE-78]: OS command injection
    // User input concatenated directly to shell command
    snprintf(cmd, sizeof(cmd), "grep '%s' /var/log/syslog", user_input);
    system(cmd);  // BAD: if user_input="'; rm -rf /; echo '", full command injection
}

void execute_safe(const char *user_input) {
    // GOOD: use execve with argv, not shell
    char *const argv[] = {"/bin/grep", user_input, "/var/log/syslog", NULL};
    // execve is safer but user_input still needs validation
    printf("execve would be called here with validated args\n");
}

/* ── CWE-22: Path Traversal ───────────────────────────────── */
void read_user_file(const char *filename) {
    char path[512];
    // VULNERABILITY [CWE-22]: Path traversal
    // User-controlled filename without sanitization
    snprintf(path, sizeof(path), "/var/data/%s", filename);
    FILE *f = fopen(path, "r");  // BAD: filename could be "../../etc/passwd"
    if (f) {
        char buf[256];
        while (fgets(buf, sizeof(buf), f)) printf("%s", buf);
        fclose(f);
    }
}

/* ── CWE-675: Double Close ───────────────────────────── */
void double_close_example() {
    FILE *f = fopen("/tmp/test.txt", "w");
    if (f) {
        fprintf(f, "data");
        fclose(f);
        // VULNERABILITY [CWE-675]: Double close
        fclose(f);  // BAD: double close — undefined behavior
    }
}

/* ── CWE-775: File Leak ──────────────────────────────── */
void file_leak_example() {
    // VULNERABILITY [CWE-775]: File descriptor leak
    FILE *f = fopen("/var/log/app.log", "r");
    // BAD: f opened but never closed on this code path
    if (!f) return;  // error path closes nothing
    printf("File opened but will leak\n");
    // missing fclose(f)
}

/* ── CWE-672: Use After Close ────────────────────────── */
void use_after_close_example() {
    FILE *f = fopen("/tmp/data.txt", "r");
    if (!f) return;
    char buf[64];
    fgets(buf, sizeof(buf), f);
    fclose(f);
    // VULNERABILITY [CWE-672]: Use after close
    fgets(buf, sizeof(buf), f);  // BAD: reading from closed handle
}

/* ── CWE-367: TOCTOU Race ─────────────────────────────────── */
void check_then_open(const char *path) {
    struct stat st;
    // VULNERABILITY [CWE-367]: TOCTOU race
    // File is checked then opened — symlink can be swapped in between
    if (access(path, R_OK) == 0) {  // CHECK: time of check
        // WINDOW: attacker replaces path with symlink to /etc/passwd
        FILE *f = fopen(path, "r");  // USE: time of use
        if (f) {
            char buf[256];
            while (fgets(buf, sizeof(buf), f)) printf("%s", buf);
            fclose(f);
        }
    }
}

void toctou_safe(const char *path) {
    // GOOD: openat + O_NOFOLLOW prevents symlink race
    int dir_fd = open("/safe_dir", O_RDONLY);
    if (dir_fd >= 0) {
        int fd = openat(dir_fd, path, O_RDONLY | O_NOFOLLOW);
        if (fd >= 0) close(fd);
        close(dir_fd);
    }
}

/* ── CWE-377: Insecure Temp File ──────────────────────────── */
void create_temp_file_unsafe() {
    char template[] = "/tmp/prefixXXXXXX";
    // VULNERABILITY [CWE-377]: Insecure temporary file
    // Predictable filename allows attacker to pre-create symlink
    // Using hardcoded path instead of mkstemp
    FILE *f = fopen("/tmp/myapp.log", "w");  // BAD: predictable path, race-able
    if (f) {
        fprintf(f, "temporary data\n");
        fclose(f);
    }
}

void create_temp_file_safe() {
    // GOOD: mkstemp creates file atomically
    char template[] = "/tmp/myapp_XXXXXX";
    int fd = mkstemp(template);
    if (fd >= 0) {
        write(fd, "safe temp data\n", 15);
        close(fd);
    }
}

/* ── CWE-61: Symlink Attack ───────────────────────────────── */
void write_log_unsafe() {
    // VULNERABILITY [CWE-61]: Symlink attack
    // If attacker creates symlink at /var/log/myapp.log -> /etc/shadow,
    // this write will corrupt /etc/shadow
    FILE *f = fopen("/var/log/myapp.log", "a");  // BAD: follows symlinks
    if (f) {
        fprintf(f, "log entry\n");
        fclose(f);
    }
}

void write_log_safe() {
    // GOOD: O_NOFOLLOW prevents following symlinks
    int fd = open("/var/log/myapp.log", O_WRONLY | O_APPEND | O_CREAT | O_NOFOLLOW, 0644);
    if (fd >= 0) {
        write(fd, "safe log entry\n", 15);
        close(fd);
    }
}

/* ── CWE-269: Privilege Escalation ────────────────────────── */
void setuid_and_revert() {
    // VULNERABILITY [CWE-269]: Privilege escalation
    // Drops privileges then fails to permanently drop them

    // Temporarily drop to nobody
    if (seteuid(65534) != 0) {  // nobody uid
        perror("seteuid failed");
        return;
    }

    // Do some unprivileged work
    printf("Running as uid: %d\n", geteuid());

    // VULNERABILITY [CWE-269]: seteuid(0) can restore root if we have saved UID 0
    // Should call setuid(65534) for permanent drop
    seteuid(0);  // BAD: restores root privileges!

    printf("Now running as uid: %d (back to root!)\n", geteuid());
}

void setuid_permanent() {
    // GOOD: permanently drop privileges
    if (setuid(65534) != 0) {
        perror("setuid failed");
        return;
    }
    // setuid(0) will fail because saved UID is also dropped
    printf("Permanently running as uid: %d\n", geteuid());
}

/* ── Main ─────────────────────────────────────────────────── */
int main() {
    printf("System security vulnerability demo\n");
    printf("This file demonstrates 6 CWE types\n");
    return 0;
}

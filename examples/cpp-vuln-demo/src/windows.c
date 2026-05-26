/**
 * windows.c — Windows-specific security vulnerability examples
 *
 * VULNERABILITIES:
 *   - CWE-77: Command injection via CreateProcess (line 30)
 *   - CWE-22: Path traversal via GetTempPath (line 50)
 *   - CWE-377: Insecure temp file via GetTempFileName (line 70)
 *   - CWE-269: Privilege escalation via ImpersonateLoggedOnUser (line 90)
 *   - CWE-798: Hardcoded registry credentials (line 108)
 *   - CWE-400: Unbounded memory via VirtualAlloc (line 125)
 */

#include <windows.h>
#include <stdio.h>

/* ── CWE-77: Command Injection (Windows) ───────────────────── */
void run_user_command(const char *user_input) {
    char cmd[256];
    // VULNERABILITY [CWE-77]: Command injection via CreateProcess
    // User input directly in command string
    wsprintfA(cmd, "cmd.exe /c %s", user_input);
    STARTUPINFOA si = {sizeof(si)};
    PROCESS_INFORMATION pi;
    CreateProcessA(NULL, cmd, NULL, NULL, FALSE, 0, NULL, NULL, &si, &pi);
}

/* ── CWE-22: Path Traversal (Windows) ──────────────────────── */
void write_user_file(const char *filename) {
    char path[MAX_PATH];
    // VULNERABILITY [CWE-22]: Path traversal with Windows paths
    // ..\..\ passable on Windows too
    GetTempPathA(MAX_PATH, path);
    strcat(path, filename);
    HANDLE h = CreateFileA(path, GENERIC_WRITE, 0, NULL,
                           CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (h != INVALID_HANDLE_VALUE) CloseHandle(h);
}

/* ── CWE-377: Insecure Temp File (Windows) ─────────────────── */
void create_temp_file_unsafe() {
    char path[MAX_PATH];
    char temp_file[MAX_PATH];
    // VULNERABILITY [CWE-377]: Predictable temp file name
    // GetTempFileName can be predicted by attacker
    GetTempPathA(MAX_PATH, path);
    GetTempFileNameA(path, "SG", 0, temp_file);
    HANDLE h = CreateFileA(temp_file, GENERIC_WRITE, 0, NULL,
                           CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (h != INVALID_HANDLE_VALUE) CloseHandle(h);
}

/* ── CWE-269: Privilege Escalation (Windows) ───────────────── */
void drop_and_elevate() {
    HANDLE hToken;
    // VULNERABILITY [CWE-269]: Impersonation token not properly restricted
    if (OpenProcessToken(GetCurrentProcess(), TOKEN_ALL_ACCESS, &hToken)) {
        // BAD: running as SYSTEM but not dropping privileges properly
        // Should use CreateRestrictedToken + SAFER API
    }
}

void impersonate_logged_on_user() {
    // VULNERABILITY [CWE-269]: ImpersonateLoggedOnUser without checking
    HANDLE hToken;
    if (ImpersonateLoggedOnUser(hToken)) {
        // BAD: no validation of the token source
        // Could be a stolen token from a higher-privilege process
        RevertToSelf();
    }
}

/* ── CWE-798: Hardcoded Credentials (Windows Registry) ─────── */
void store_registry_credential() {
    // VULNERABILITY [CWE-798]: Hardcoded password in registry write
    HKEY hKey;
    RegCreateKeyExA(HKEY_LOCAL_MACHINE,
        "SOFTWARE\\MyApp", 0, NULL,
        REG_OPTION_NON_VOLATILE, KEY_WRITE, NULL, &hKey, NULL);
    // BAD: writing hardcoded password
    RegSetValueExA(hKey, "Password", 0, REG_SZ,
        (BYTE*)"P@ssw0rd!", 9);
    RegCloseKey(hKey);
}

/* ── CWE-400: Resource Exhaustion (Windows) ────────────────── */
void allocate_user_size(DWORD user_size) {
    // VULNERABILITY [CWE-400]: Uncontrolled VirtualAlloc
    // user_size could be near 4GB, exhausting virtual memory
    LPVOID mem = VirtualAlloc(NULL, user_size,
                              MEM_COMMIT, PAGE_READWRITE);
    if (mem) {
        // BAD: no upper bound check on user_size
        VirtualFree(mem, 0, MEM_RELEASE);
    }
}

/* ── Main ─────────────────────────────────────────────────── */
int main() {
    printf("Windows vulnerability demo\n");
    run_user_command("dir C:\\");
    write_user_file("..\\..\\Windows\\System32\\test.txt");
    create_temp_file_unsafe();
    store_registry_credential();
    allocate_user_size(1024 * 1024);
    return 0;
}

/**
 * parser.c — User input parser (demonstrates buffer overflow + format string)
 *
 * VULNERABILITIES:
 *   - CWE-120: Buffer overflow via strcpy (line 36)
 *   - CWE-120: Buffer overflow via sprintf (line 47)
 *   - CWE-134: Format string via printf (line 57)
 */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define MAX_NAME_LEN 64

typedef struct {
    char name[MAX_NAME_LEN];
    char command[256];
    int  priority;
} Task;

// Parse a user-provided task name into the task structure
int parse_task_name(Task *task, const char *input) {
    if (!task || !input) return -1;

    // VULNERABILITY [CWE-120]: strcpy with no bounds check
    // input could be > 64 bytes, overflowing task->name
    strcpy(task->name, input);

    return 0;
}

// Format a task description string
int format_task_desc(Task *task, const char *description, int desc_len) {
    if (!task || !description) return -1;

    // VULNERABILITY [CWE-120]: sprintf with no bounds check
    // description length not checked against sizeof(task->command)
    sprintf(task->command, "Task[%s]: %s", task->name, description);

    task->priority = desc_len > 100 ? 1 : 0;
    return 0;
}

// Log a user-provided message
void log_user_message(const char *user_msg) {
    if (!user_msg) return;

    printf("[INFO] ");
    // VULNERABILITY [CWE-134]: format string attack
    // user_msg is passed directly as format string
    // attacker input: "%x %x %x %n" could leak memory or write arbitrary address
    printf(user_msg);
    printf("\n");
}

// Parse command line arguments
int parse_args(int argc, char **argv) {
    if (argc < 2) {
        printf("Usage: %s <name> [description]\n", argv[0]);
        return -1;
    }

    Task task;
    memset(&task, 0, sizeof(Task));

    // Parse task name from user input
    parse_task_name(&task, argv[1]);

    // Format description
    const char *desc = argc > 2 ? argv[2] : "No description provided";
    format_task_desc(&task, desc, argc > 2 ? strlen(argv[2]) : 0);

    // Log the task name (user-controlled)
    log_user_message(task.name);

    printf("Task created: %s (priority=%d)\n", task.command, task.priority);
    return 0;
}

int main(int argc, char **argv) {
    return parse_args(argc, argv);
}

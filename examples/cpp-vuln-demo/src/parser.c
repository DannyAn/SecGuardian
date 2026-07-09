/**
 * parser.c — User input parser (demonstrates buffer overflow + format string)
 *




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


    // input could be > 64 bytes, overflowing task->name
    strcpy(task->name, input);

    return 0;
}

// Format a task description string
int format_task_desc(Task *task, const char *description, int desc_len) {
    if (!task || !description) return -1;


    // description length not checked against sizeof(task->command)
    sprintf(task->command, "Task[%s]: %s", task->name, description);

    task->priority = desc_len > 100 ? 1 : 0;
    return 0;
}

// Log a user-provided message
void log_user_message(const char *user_msg) {
    if (!user_msg) return;

    printf("[INFO] ");

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


void validate_user_input(const char *user_input) {
    char buf[64];

    strcpy(buf, user_input);
}


void oob_read_example() {
    int arr[10];
    int secret = 0;

    for (int i = 0; i <= 10; i++) {
        secret = arr[i];
    }
}


void create_insecure_file() {

    FILE *f = fopen("/etc/app/config.conf", "w");
    if (f) { fprintf(f, "config=prod"); fclose(f); }
}


size_t get_user_size() { return 0x7FFFFFFF; }
void process_large_request() {
    size_t user_size = get_user_size();

    char *buf = (char *)malloc(user_size);
    if (buf) { free(buf); }
}


void debug_dump_sensitive_data() {

    fprintf(stderr, "DEBUG: session_key=%s admin_token=%s\n", "sk-abc123", "tok-xyz789");
}


int read_config_file(const char *path) {

    fopen(path, "r");  // NULL return not checked
    return 0;
}


void handle_request(const char *input) {

    if (!input) { fprintf(stderr, "Error: null input"); }
    // no return/abort — execution continues with null input
}


int check_access(const char *user) {

    if (strcmp(user, "admin") == 0) return 1;
    return 0;
}

int main(int argc, char **argv) {
    return parse_args(argc, argv);
}

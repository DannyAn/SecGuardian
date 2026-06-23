import json, os, re, sys
from glob import glob

"""
检查 commands/*.md 中嵌入式 bash/Python 模板的常见错误。

检测模式：bash 代码块中 `VAR=value` 赋值给 shell 变量，
然后 Python heredoc 通过 `os.environ['VAR']` 读取——如果缺少 `export`，
Python 进程拿不到该变量。

在每个 bash 代码块中独立扫描（不同代码块间变量不共享）。
"""

def get_project_root():
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def find_command_files(root):
    return sorted(glob(os.path.join(root, 'commands', '*.md')))


def parse_fenced_blocks(text):
    """提取所有围栏代码块，返回 [(lang, start_line_0based, content)]"""
    blocks = []
    lines = text.split('\n')
    i = 0
    while i < len(lines):
        m = re.match(r'^```(\w*)\s*$', lines[i])
        if m:
            lang = m.group(1)
            start_line = i + 1
            content_lines = []
            i += 1
            while i < len(lines) and not re.match(r'^```(\w*)\s*$', lines[i]):
                content_lines.append(lines[i])
                i += 1
            blocks.append((lang, start_line, '\n'.join(content_lines)))
            # 不要跳过 closing fence - 如果它是带语言标记的 ```bash，下次迭代作为 opening 处理
            continue
        i += 1
    return blocks


def find_python_heredocs(lines):
    """在 bash 代码块文本中查找 Python heredoc"""
    heredocs = []
    i = 0
    while i < len(lines):
        m = re.match(r'^\s*python3?\s*<<\s*\'?(\w+)\'?\s*(?:#.*)?$', lines[i])
        if m:
            delimiter = m.group(1)
            start = i + 1
            py_lines = []
            i += 1
            while i < len(lines) and not lines[i].strip() == delimiter:
                py_lines.append(lines[i])
                i += 1
            heredocs.append((start, '\n'.join(py_lines)))
        i += 1
    return heredocs


def find_bash_assignments(text):
    """找出 bash 赋值和 export 的变量"""
    assigned = set()
    exported = set()
    BASH_BUILTINS = {'PATH', 'HOME', 'USER', 'PWD', 'SHELL', 'TERM',
                     'LANG', 'BASH_', 'HOSTNAME', 'local', 'declare',
                     'typeset', 'LC_ALL', 'LC_CTYPE', 'IFS', 'PS1',
                     'LD_LIBRARY_PATH', 'DYLD_LIBRARY_PATH'}

    for line in text.split('\n'):
        stripped = line.strip()
        if not stripped or stripped.startswith('#'):
            continue

        export_m = re.match(r'^export\s+([A-Za-z_][A-Za-z0-9_]*)(?:=|$|\s)', stripped)
        if export_m:
            exported.add(export_m.group(1))
            continue

        assign_m = re.match(r'^([A-Za-z_][A-Za-z0-9_]*)=(.*)', stripped)
        if assign_m:
            var_name = assign_m.group(1)
            if var_name not in BASH_BUILTINS:
                assigned.add(var_name)

    return assigned, exported


def find_os_environ_refs(python_code):
    """从 Python 代码中提取所有 os.environ 引用"""
    refs = []
    # 两种形式: os.environ['KEY'] (方括号) 和 os.environ.get('KEY') (方法调用)
    for m in re.finditer(
        r"os\.environ\[['\"]([^'\"]+)['\"]\]"
        r"|os\.environ\.get\(['\"]([^'\"]+)['\"]",
        python_code
    ):
        refs.append(m.group(1) or m.group(2))
    return refs


def check_file(filepath):
    """检查单个 commands/*.md 文件"""
    with open(filepath) as f:
        content = f.read()

    blocks = parse_fenced_blocks(content)
    violations = []
    passed = 0

    for lang, start_line, block_text in blocks:
        if lang not in ('bash', 'sh', ''):
            continue

        lines = block_text.split('\n')
        heredocs = find_python_heredocs(lines)
        if not heredocs:
            continue

        assigned, exported = find_bash_assignments(block_text)

        for heredoc_start, py_code in heredocs:
            refs = find_os_environ_refs(py_code)
            for var_name in refs:
                if var_name in assigned and var_name not in exported:
                    violations.append(
                        "[%s:%d] `%s` bash 变量赋值后未 export，"
                        "Python heredoc 中 os.environ['%s'] 读不到" %
                        (os.path.basename(filepath),
                         start_line + heredoc_start, var_name, var_name))
                elif var_name not in assigned and var_name not in exported:
                    violations.append(
                        "[%s:%d] `%s` 既未在 bash 中赋值也未 export，"
                        "Python heredoc 中 os.environ['%s'] 读不到" %
                        (os.path.basename(filepath),
                         start_line + heredoc_start, var_name, var_name))
                else:
                    passed += 1

    return violations, passed


def main():
    root = get_project_root()
    files = find_command_files(root)

    total_violations = 0
    total_passed = 0

    for f in files:
        violations, passed = check_file(f)
        total_passed += passed
        for v in violations:
            print(f"  ❌ {v}")
            total_violations += 1

    if total_violations > 0:
        print(f"\n❌ {total_violations} environment variable export violations found")
        print("   All bash → Python heredoc env vars must use `export VAR=...` syntax")
        sys.exit(1)
    else:
        print(f"  ✅ Command templates: {total_passed} os.environ references validated, 0 violations")
        sys.exit(0)


if __name__ == '__main__':
    main()

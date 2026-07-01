# TASK-005: Renderer — report.html 生成

## Goal

新增 render_html_report()，从 findings_data 直接生成 HTML 报告，不解析 report.md。

## Done

- [ ] render_html_report() 函数实现
- [ ] Python f-string 构建 HTML 骨架（doctype + head + style + body）
- [ ] 嵌入 CSS（字体、颜色、表格样式、代码高亮、严重度色标）
- [ ] 生成全部 5 节 HTML 内容
- [ ] 代码块用 pre + code，表格用 table + tr + th + td
- [ ] 写入 scan-root/report.html
- [ ] main() 调用

## Design

与 generate_report_md() 共用同一份 findings_data。HTML helper：

```python
def esc(text):
    return str(text).replace("&","&amp;").replace("<","&lt;").replace(">","&gt;")
```

## Files

- scripts/render-report.py

## Verification

```bash
grep -c "<html" .codeagent/.../report.html
grep -c "severity-critical" .codeagent/.../report.html
file .codeagent/.../report.html
```

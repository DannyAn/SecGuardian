# TASK-004: H-2 Go 构建错误追踪

> **文件**: scripts/package.sh
> **目标**: 添加 wait 退出码数组记录，不再吞掉构建失败

## 验证

- package.sh 构建流程捕获每个平台的 exit code

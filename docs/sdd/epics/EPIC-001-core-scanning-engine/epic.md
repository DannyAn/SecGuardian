# EPIC-001: Core Scanning Engine

> **状态**: ✅ 已完成（持续改进中）
> **周期**: 2026-05 ~ 2026-06
> **目标**: 构建高质量的安全扫描引擎，覆盖输出协议、检测器质量、验证体系

## 概述

Core Scanning Engine 是 SecGuardian 的核心能力层，负责从代码中检测安全问题并以结构化格式输出。本 Epic 涵盖从输出协议演化到检测器质量增强的完整链路。

## 包含 Feature

| Feature | 状态 | 说明 |
|---------|------|------|
| [FEATURE-001: Output Protocol Evolution](./FEATURE-001-output-protocol/) | ✅ 已完成 | 输出协议从 v2 摘要型演进到 v5 目录树 |
| [FEATURE-002: Detector Quality Enhancement](./FEATURE-002-detector-quality/) | ✅ 已完成 | 67 个检测器统一模板、误报消除、证据增强 |

## 架构影响

本 Epic 建立了 SecGuardian 的核心架构模式：

- **AI/Renderer 分离**：AI 输出结构化 findings.json，render-report.py 负责格式化
- **四段式标准**：每个 Finding 必须包含 Location → Evidence → Impact → Fix
- **目录树输出**：按 detector 组织的 findings 目录树，解决大项目 token 爆炸
- **统一检测器模板**：precision + confidence 元数据、MUST/SHOULD/MAY 证据分层

## 关键里程碑

| 日期 | 里程碑 |
|------|--------|
| 2026-06-05 | 输出协议 v3.0 设计完成（四段式 + SARIF 双轨） |
| 2026-06-07 | 输出协议 v5.0 设计完成（目录树架构） |
| 2026-06-11 | 检测器质量增强设计批准（统一模板 + 证据绑定） |
| 2026-06-14 | 67 个检测器全部完成模板升级 |

## 验证体系

本 Epic 同时催生了 L1-L5 分层验证体系（详见 `scripts/self-check.sh` 等），确保每次修改都有对应层级的自动化验证。

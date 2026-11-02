# 本机 AI Skill + MCP 管理器（macOS）

版本：V0.2（2026-09-23） · 产品方案精简稿

## 定位

参考 [Skills Manager](https://github.com/xingkongliang/skills-manager/blob/main/README.zh-CN.md) 的「统一技能库 → 分发到各 AI 工具」模式，做一个 Mac 原生应用，把本机 **Skill 文件夹**和 **MCP Server 配置条目**放在同一个界面管理。首版覆盖 WorkBuddy、Claude Code、Codex、Antigravity、Cursor、Qoder；支持用户级与项目级。

**竞品边界：**Skills Manager 已支持 Skill 的全局工作区与项目工作区、中央库双向同步、软链接/复制和多工具分发。全局/项目级 Skill 管理不是本产品的新能力；主要新增价值是把 MCP 条目管理接到同一工作流，并采用 Mac 原生界面。

## 核心模型

| 对象 | 中央库保存 | 启用到目标工具 | 停用 |
| --- | --- | --- | --- |
| Skill | 含 `SKILL.md` 的完整文件夹 | 在目标 Skill 目录创建软链接或复制文件夹 | 撤销本应用创建的链接/副本 |
| MCP | 一个 Server 的配置模板 | 将一个 Server 条目合并到目标客户端的配置文件 | 使用客户端原生开关，或撤销本应用写入的条目 |

Skill 主要是文件夹引用或复制。MCP 通常是 JSON/TOML 文件中的一个条目，因此不能把整个配置文件做软链接，否则会影响用户原有的其他 Server。MCP 模板可能含环境变量值；首版只保存在本机且限制文件权限，后续增加钥匙串托管。

## 主界面

```text
┌────────────────┬──────────────────────────────────────────────────────┐
│ 技能库         │ [Skills] [MCP] [项目]     搜索 ____  [导入] [新建] │
│ 全部工具       │                                                      │
│ Claude Code    │ 名称         类型    Claude  Codex  Cursor  ...      │
│ Codex          │ code-review  Skill     ✓      ✓       —            │
│ Cursor         │ github       MCP       ✓      —       ✓            │
│ Antigravity    │                                                      │
│ Qoder          │ 详情：内容、来源、全局/项目、同步方式、启停         │
│ WorkBuddy      │                                                      │
└────────────────┴──────────────────────────────────────────────────────┘
```

卡片上的工具开关是主操作。点击后选择「全局」或具体项目；Skill 还可选「软链接」或「复制」。复制模式会提示中央库与目标副本是否一致。用户可从本地目录或 ZIP 导入 Skill，从已有客户端配置导入 MCP。

## 两条流程

```mermaid
flowchart LR
  A[扫描各工具现有能力] --> B[展示实际安装情况]
  B --> C[导入中央库]
  C --> D[选择工具与全局/项目作用域]
  D --> E[预览新增/删除的文件或配置条目]
  E --> F[写入目标并复查]
```

### Skill

1. 扫描六个客户端的已知 Skill 目录，包括用户级和用户添加的项目级目录。
2. 区分「本应用分发」「用户手动安装」「客户端或插件托管」。外部安装可导入中央库，未导入前不移动。
3. 启用时创建链接或复制完整文件夹。同名目标已存在时提示跳过或替换；替换前备份。
4. 停用只撤销本应用的分发，不直接删除用户手动安装或插件市场中的 Skill。

### MCP

1. 扫描目标工具的 MCP 配置，按 Server 名称列出命令/URL、配置来源及作用域。
2. 用户可把现有 Server 导入中央库，或手动新建一个模板。
3. 启用时把模板转换成目标工具支持的字段，并将该 Server 条目合并进配置文件。
4. 停用时优先用客户端原生开关；否则仅撤销本应用写入的 Server 条目。原有同名 Server 先展示差异，不直接覆盖。
5. 配置修改前备份，写入后重新解析。MCP 的「停用」指客户端后续不再加载该 Server，不代表结束当前 MCP 进程。

## 首版功能

| 优先级 | 内容 |
| --- | --- |
| P0 | 六客户端本地扫描；Antigravity IDE/CLI 分开适配 |
| P0 | 全局与项目级 Skill 清单、中央库导入、软链接/复制分发、启停 |
| P0 | 全局与项目级 MCP 清单、模板导入/新建、配置条目启停 |
| P0 | 同名冲突提示、变更预览、备份与恢复；项目手动添加与路径修正 |
| P1 | Git/市场安装 Skill、批量启停、预设组合、MCP 连通性测试 |
| 后续 | 云同步、团队管理、Windows/Linux |

六个客户端首版都需要**可发现、可查看**。具体来源能否直接启停，取决于该客户端版本及来源类型。若 Skill/MCP 由插件或应用内部管理，显示「由客户端管理」及打开设置入口，不伪装成可编辑文件。

## 实现方向

- SwiftUI 做 Mac 原生主界面，AppKit 承载窗口和系统弹窗；中央库仅保存用户主动导入的 Skill 与 MCP 模板，目标客户端文件仍是实际生效来源。
- 每个客户端一个适配器：扫描路径、读取内容、生成差异、写入或撤销、复查。适配器声明支持的作用域和操作能力。
- 修改配置时读取最新文件，精确编辑目标条目，预览、备份、写入、复查。发现并发改动或解析失败就停止。
- 不需要常驻后台服务。打开应用或手动刷新时扫描；文件监听可在后续增强。

## MVP 验收例子

1. 导入一个 Skill，启用到 Claude Code、Codex 全局和 Cursor 某项目；停用 Codex 后另外两端仍保留。
2. 从 Cursor 导入一个 MCP Server，启用到 Claude Code 和 Qoder；目标原有 Server 保持不变，停用其中一端只撤销该端。
3. 对用户手动安装、插件托管、同名冲突和格式错误的配置，界面指出实际位置，不误删或覆盖。

## 需实机核对

| 项目 | 原因 |
| --- | --- |
| WorkBuddy Skill 的本地路径与市场安装位置 | 官方资料明确有市场管理；不同产品线可能不同 |
| Antigravity IDE 与 CLI 的配置来源 | 官方文档区分两套路径 |
| Qoder 项目级 MCP 的配置位置 | 按本机安装版本核对 |
| 项目列表 | 首版由用户添加，避免全盘扫描不完整或过慢 |

资料：[Skills Manager README](https://github.com/xingkongliang/skills-manager/blob/main/README.zh-CN.md)、[Claude Code Skills](https://code.claude.com/docs/en/skills)、[OpenAI Docs：Codex Skills](https://learn.chatgpt.com/docs/build-skills)、[OpenAI Docs：Codex MCP](https://learn.chatgpt.com/docs/extend/mcp?surface=cli)、[Cursor Skills](https://cursor.com/docs/skills)、[Cursor MCP](https://docs.cursor.com/context/model-context-protocol)、[Antigravity Skills](https://antigravity.google/docs/skills)、[Antigravity MCP](https://antigravity.google/docs/ide-mcp)、[Qoder Skills](https://docs.qoder.com/extensions/skills)、[WorkBuddy MCP](https://www.workbuddy.ai/docs/zh/workbuddy/From-Beginner-to-Expert-Guide/Function-Description/MCP-Guide)。

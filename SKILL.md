---
name: openclaw-feishu-send-file
version: "1.0.2"
description: 通过 OpenClaw 在飞书聊天中发送文件附件。当用户说"发文件"、"把文件发给我"、"发送附件"、"发报告"或 Agent 需要向飞书用户发送本地文件时触发。支持两种方式：OpenClaw CLI（默认首选，通用所有渠道）和飞书 API 脚本（备选，飞书专用，无路径限制）。
---

# OpenClaw 飞书文件发送

让 AI Agent 在飞书聊天中直接发送文件附件，而非文本链接。

## 方式一：OpenClaw CLI（默认首选）

文件须先拷贝到 CLI 白名单目录，否则会**静默降级为文本链接但仍报成功**。

白名单目录：`/tmp/openclaw/` · `~/.openclaw/media/` · `~/.openclaw/workspace/` · `~/.openclaw/sandboxes/`

使用 `mktemp -d` 创建随机子目录，避免同名文件覆盖，无需手动清理（`/tmp` 由系统自动回收）。

```bash
SEND_DIR=$(mktemp -d /tmp/openclaw/send-XXXXXX)
cp <文件路径> "$SEND_DIR/<文件名>"
openclaw message send \
  --channel feishu --account erzhuang \
  --target "user:<open_id>" \
  --message "说明文字 [via OpenClaw CLI]" \
  --media "$SEND_DIR/<文件名>"
```

**必须指定 `--account`**，否则报 `appId and appSecret are required`。跨应用发送会报 `open_id cross app`。

`--message` 末尾已自带 `[via OpenClaw CLI]` 标记，无需额外告知。

## 方式二：飞书 API 脚本（备选，飞书专用）

无路径限制，适用于文件不在白名单目录且不想中转的场景。

首次使用前确保脚本有执行权限：

```bash
chmod +x <skill安装路径>/openclaw-feishu-send-file/scripts/send-file.sh
```

```bash
bash <skill安装路径>/openclaw-feishu-send-file/scripts/send-file.sh <文件路径> <open_id> [消息文本] [--account erzhuang|main]
```

脚本从 `~/.openclaw/openclaw.json` 读取凭据，不单独存储敏感信息。

脚本执行完毕会自动输出 `[via 飞书 API]` 标记，无需额外告知。

## 常见陷阱

- CLI 文件路径不在白名单时**静默降级为文本链接**，但仍返回 `✅ Sent`
- `open_id` 是应用维度的，不同飞书应用的同一用户 `open_id` 不同
- agent workspace 目录（如 `~/.openclaw/agents/*/workspace/`）在 CLI 模式下不在白名单中

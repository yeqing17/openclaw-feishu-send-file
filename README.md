# openclaw-feishu-send-file

通过 OpenClaw 在飞书聊天中直接发送文件附件的 Agent Skill。

## 安装

下载 [.skill 文件](https://github.com/yeqing17/openclaw-feishu-send-file/releases/download/v1.0.2/openclaw-feishu-send-file.skill) 安装，或克隆到 skill目录：

```bash
git clone https://github.com/yeqing17/openclaw-feishu-send-file.git ~/.openclaw/skills/openclaw-feishu-send-file
```

## 功能

Agent 在需要向飞书用户发送文件时会自动触发此技能，支持两种方式：

- **OpenClaw CLI**（默认首选，通用所有渠道）
- **飞书 API 脚本**（备选，飞书专用，无路径限制）

详见 [SKILL.md](SKILL.md)。

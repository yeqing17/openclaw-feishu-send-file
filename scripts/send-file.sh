#!/bin/bash
# send-file.sh - 通过飞书开放 API 发送文件给指定用户/群聊
# 用法: ./send-file.sh <文件路径> <接收者ID> [消息文本] [--account erzhuang]
# 接收者ID: user:ou_xxx 或 chat:oc_xxx 或 ou_xxx(单聊) 或 oc_xxx(群聊)
#
# 示例:
#   ./send-file.sh /tmp/testfile.pdf ou_xxxxx "📄 文件说明"
#   ./send-file.sh /tmp/testfile.pdf chat:oc_xxxxx "文件说明" --account main

set -euo pipefail

# 从 openclaw.json 读取账号凭据，不单独存储敏感信息
CONFIG_FILE="$HOME/.openclaw/openclaw.json"

# ========== 参数解析（合并账号选择与位置参数）==========

FILE_PATH=""
OPEN_ID=""
MSG_TEXT=""
ACCOUNT="erzhuang"
args=("$@")
i=0
while [ $i -lt ${#args[@]} ]; do
    case "${args[$i]}" in
        --account)
            i=$((i+1))
            ACCOUNT="${args[$i]:-erzhuang}"
            ;;
        *)
            if [ -z "$FILE_PATH" ]; then
                FILE_PATH="${args[$i]}"
            elif [ -z "$OPEN_ID" ]; then
                OPEN_ID="${args[$i]}"
            else
                MSG_TEXT="${args[$i]}"
            fi
            ;;
    esac
    i=$((i+1))
done

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ 配置文件不存在: $CONFIG_FILE" >&2
    exit 1
fi

# 读取账号凭据（从 openclaw.json → channels.feishu.accounts）
APP_ID=$(python3 -c "
import json
try:
    d=json.load(open('$CONFIG_FILE'))
    print(d['channels']['feishu']['accounts']['$ACCOUNT']['appId'])
except (KeyError, TypeError):
    d=json.load(open('$CONFIG_FILE'))
    print(d['channels']['feishu']['appId'])
")
APP_SECRET=$(python3 -c "
import json
try:
    d=json.load(open('$CONFIG_FILE'))
    print(d['channels']['feishu']['accounts']['$ACCOUNT']['appSecret'])
except (KeyError, TypeError):
    d=json.load(open('$CONFIG_FILE'))
    print(d['channels']['feishu']['appSecret'])
")

if [ -z "$APP_ID" ] || [ -z "$APP_SECRET" ]; then
    echo "❌ 账号 '$ACCOUNT' 不存在于 $CONFIG_FILE" >&2
    exit 1
fi

if [ -z "$FILE_PATH" ] || [ -z "$OPEN_ID" ]; then
    echo "用法: $0 <文件路径> <接收者ID> [消息文本] [--account erzhuang|main]" >&2
    echo "" >&2
    echo "接收者ID格式:" >&2
    echo "  ou_xxxxx     单聊（open_id）" >&2
    echo "  user:ou_xxx  单聊（带前缀）" >&2
    echo "  oc_xxxxx     群聊（chat_id）" >&2
    echo "  chat:oc_xxx  群聊（带前缀）" >&2
    echo "" >&2
    echo "示例:" >&2
    echo "  $0 /tmp/testfile.pdf ou_xxxxx 📄 文件" >&2
    echo "  $0 /tmp/data.pdf chat:oc_xxxxx --account main" >&2
    exit 1
fi

# 校验文件
if [ ! -f "$FILE_PATH" ]; then
    echo "❌ 文件不存在: $FILE_PATH" >&2
    exit 1
fi

FILE_NAME=$(basename "$FILE_PATH")
FILE_SIZE=$(du -h "$FILE_PATH" | cut -f1)

# 自动追加方式标记到消息文本
if [ -n "$MSG_TEXT" ]; then
    MSG_TEXT="$MSG_TEXT [via 飞书 API]"
else
    MSG_TEXT="[via 飞书 API]"
fi

# ========== 执行 ==========

echo "📎 发送文件: $FILE_NAME ($FILE_SIZE)" >&2
echo "👤 接收者:   $OPEN_ID" >&2
echo "🤖 账号:     $ACCOUNT" >&2
echo "" >&2

# Step 1: 获取 tenant_access_token
TOKEN=$(curl -sf -X POST 'https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal' \
    -H 'Content-Type: application/json' \
    -d "{\"app_id\":\"$APP_ID\",\"app_secret\":\"$APP_SECRET\"}" | python3 -c 'import sys,json;print(json.load(sys.stdin)["tenant_access_token"])')

if [ -z "$TOKEN" ]; then
    echo "❌ 获取 token 失败" >&2
    exit 1
fi

# Step 2: 上传文件（file_type=stream 通用类型，支持所有格式）
echo "⬆️ 上传中..." >&2
UPLOAD_RESP=$(curl -sf -X POST 'https://open.feishu.cn/open-apis/im/v1/files' \
    -H "Authorization: Bearer $TOKEN" \
    -F 'file_type=stream' \
    -F "file_name=$FILE_NAME" \
    -F "file=@$FILE_PATH")

FILE_KEY=$(echo "$UPLOAD_RESP" | python3 -c 'import sys,json;print(json.load(sys.stdin)["data"]["file_key"])')

if [ -z "$FILE_KEY" ]; then
    echo "❌ 文件上传失败: $UPLOAD_RESP" >&2
    exit 1
fi

echo "   file_key: $FILE_KEY" >&2

# Step 3: 发送文件消息
echo "📨 发送中..." >&2

# 根据 OPEN_ID 前缀自动判断 receive_id_type
if [[ "$OPEN_ID" == chat:* ]]; then
    RECEIVE_ID_TYPE="chat_id"
    RECEIVE_ID="${OPEN_ID#chat:}"
    echo "💬 群聊模式" >&2
elif [[ "$OPEN_ID" == oc_* ]]; then
    RECEIVE_ID_TYPE="chat_id"
    RECEIVE_ID="$OPEN_ID"
    echo "💬 群聊模式" >&2
elif [[ "$OPEN_ID" == user:* ]]; then
    RECEIVE_ID_TYPE="open_id"
    RECEIVE_ID="${OPEN_ID#user:}"
    echo "👤 单聊模式" >&2
else
    RECEIVE_ID_TYPE="open_id"
    RECEIVE_ID="$OPEN_ID"
    echo "👤 单聊模式" >&2
fi

# 先发文本消息（如果有的话）
if [ -n "$MSG_TEXT" ]; then
    TEXT_RESULT=$(curl -sf -X POST "https://open.feishu.cn/open-apis/im/v1/messages?receive_id_type=$RECEIVE_ID_TYPE" \
        -H "Authorization: Bearer $TOKEN" \
        -H 'Content-Type: application/json' \
        -d "{\"receive_id\":\"$RECEIVE_ID\",\"msg_type\":\"text\",\"content\":\"{\\\"text\\\":\\\"$MSG_TEXT\\\"}\"}" 2>&1 || true)
fi

# 发送文件消息
SEND_RESP=$(curl -sf -X POST "https://open.feishu.cn/open-apis/im/v1/messages?receive_id_type=$RECEIVE_ID_TYPE" \
    -H "Authorization: Bearer $TOKEN" \
    -H 'Content-Type: application/json' \
    -d "{\"receive_id\":\"$RECEIVE_ID\",\"msg_type\":\"file\",\"content\":\"{\\\"file_key\\\":\\\"$FILE_KEY\\\"}\"}")

MSG_ID=$(echo "$SEND_RESP" | python3 -c 'import sys,json;print(json.load(sys.stdin)["data"]["message_id"])' 2>/dev/null || echo "unknown")

echo "" >&2
echo "✅ 发送成功! message_id: $MSG_ID [via 飞书 API]"

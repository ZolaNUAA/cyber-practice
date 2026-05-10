# TITLE: 背景 — IDS/IPS 概念
# STEP: 1
# MINUTES: 8

### WHY

IDS（入侵检测系统）和 IPS（入侵防御系统）是网络安全监控的核心组件。

**IDS vs IPS**：
- IDS：检测+告警（被动）
- IPS：检测+阻止（主动，inline 部署）

**告警分析师的日常**：
1. 接收告警 → 2. 分级（triage）→ 3. 调查 → 4. 响应

告警格式通常为 JSON（如 Suricata EVE 格式），包含：
- 时间戳、源/目标 IP 和端口
- 告警签名和分类
- 严重度等级
- HTTP 详情（URL、User-Agent）

### DO

本步骤不需要操作。理解概念。

### CHECK

IDS 和 IPS 的核心区别是什么？

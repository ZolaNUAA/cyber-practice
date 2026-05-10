### 答案

三个请求的 HTTP Stream 内容：
1. GET / -> 返回 HTML 页面
2. GET /api/status -> 返回 JSON {"status": "ok"}
3. GET /beacon?id=101 -> 返回 {"received": true} (C2信标模式)

/beacon 端点最可疑，看起来像恶意软件的信标通信。
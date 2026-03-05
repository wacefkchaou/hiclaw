# 常见问题

- [Manager Agent 启动超时](#manager-agent-启动超时)
- [局域网其他电脑如何访问 Web 端](#局域网其他电脑如何访问-web-端)
- [本地访问 Matrix 服务器不通](#本地访问-matrix-服务器不通)
- [如何主动指挥 Worker](#如何主动指挥-worker)
- [如何切换 Manager 的模型](#如何切换-manager-的模型)

---

## Manager Agent 启动超时

安装完成后如果 Manager Agent 迟迟没有响应，进容器查看日志：

```bash
docker exec -it hiclaw-manager cat /var/log/hiclaw/manager-agent.log
```

**情况一：日志中有进程退出记录**

可能是 Docker VM 分配的内存不足。建议将内存调整到 4GB 以上：Docker Desktop → Settings → Resources → Memory。调整后重新执行安装命令。

**情况二：日志中没有进程退出，但某些组件起不来**

可能是配置脏数据导致的。建议到原安装目录重新执行安装命令，选择**删除重装**：

```bash
bash <(curl -sSL https://higress.ai/hiclaw/install.sh)
```

安装脚本检测到已有安装时会询问处理方式，选择删除后重装即可清除脏数据。

---

## 局域网其他电脑如何访问 Web 端

**访问 Element Web**

在局域网其他电脑的浏览器中输入：

```
http://<局域网IP>:18088
```

浏览器可能会提示"不安全"或"不支持"，忽略提示直接点 Continue 进入即可。

**修改 Matrix Server 地址**

默认配置的 Matrix Server 域名解析到 `localhost`，在其他电脑上无法连通。登录 Element Web 时，需要将 Matrix Server 地址改为：

```
http://<局域网IP>:18080
```

例如局域网 IP 是 `192.168.1.100`，则填写 `http://192.168.1.100:18080`。

---

## 本地访问 Matrix 服务器不通

如果在本机也无法连接 Matrix 服务器，请检查浏览器或系统是否开启了代理。`*-local.hiclaw.io` 域名默认解析到 `127.0.0.1`，开启代理后请求会被转发到代理服务器，无法到达本地服务。

关闭代理，或将 `*-local.hiclaw.io` / `127.0.0.1` 加入代理的绕过列表即可。

---

## 如何主动指挥 Worker

创建 Worker 后，Manager 会自动将你和 Worker 拉入同一个群聊房间。在群聊中，必须 **@ Worker** 才能让它响应，没有 @ 的消息会被忽略。

在 Element 等客户端中，输入 `@` 后再输入 Worker 昵称的首字母，才会出现补全列表，选择对应用户即可。

也可以点击 Worker 的头像，进入**私聊**。私聊中不需要 @，每条消息都会触发 Worker 响应。但注意：私聊对 Manager 不可见，Manager 不会感知到这部分对话内容。

---

## 如何切换 Manager 的模型

**单供应商情况**

在 Higress 控制台，将 `default-ai-route` 这个路由配置到你的模型供应商。然后直接告诉 Manager 你想使用的具体模型名（例如 `qwen3.5-plus`）。Manager 会先用该模型名发起一次联通测试，测试通过后自动完成切换。

**多供应商情况**

在 Higress 控制台，对 `default-ai-route` 路由按模型名前缀或正则表达式配置不同的供应商。之后的流程与单供应商完全一致——告诉 Manager 模型名，它会自动完成测试和切换。

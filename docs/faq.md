# FAQ

- [Manager Agent startup timeout](#manager-agent-startup-timeout)
- [Accessing the web UI from other devices on the LAN](#accessing-the-web-ui-from-other-devices-on-the-lan)
- [Cannot connect to Matrix server locally](#cannot-connect-to-matrix-server-locally)
- [How to talk to a Worker directly](#how-to-talk-to-a-worker-directly)
- [How to switch the Manager's model](#how-to-switch-the-managers-model)

---

## Manager Agent startup timeout

If the Manager Agent is unresponsive after installation, check the logs inside the container:

```bash
docker exec -it hiclaw-manager cat /var/log/hiclaw/manager-agent.log
```

**Case 1: Log shows a process exit**

The Docker VM may not have enough memory. Increase it to at least 4GB: Docker Desktop → Settings → Resources → Memory. Then re-run the install command.

**Case 2: No process exit in logs, but some components won't start**

This is likely caused by stale config data. Re-run the install command from the original install directory and choose **delete and reinstall**:

```bash
bash <(curl -sSL https://higress.ai/hiclaw/install.sh)
```

When the installer detects an existing installation, it will ask how to proceed. Choosing delete will wipe the stale data and start fresh.

---

## Accessing the web UI from other devices on the LAN

**Accessing Element Web**

On another device on the same network, open a browser and go to:

```
http://<LAN-IP>:18088
```

The browser may warn about an insecure connection — ignore it and click Continue.

**Updating the Matrix Server address**

The default Matrix Server hostname resolves to `localhost`, which won't work from other devices. When logging into Element Web, change the Matrix Server address to:

```
http://<LAN-IP>:18080
```

For example, if your LAN IP is `192.168.1.100`, enter `http://192.168.1.100:18080`.

---

## Cannot connect to Matrix server locally

If the Matrix server is unreachable even on the local machine, check whether a proxy is enabled in your browser or system. The `*-local.hiclaw.io` domain resolves to `127.0.0.1` by default — if traffic is routed through a proxy, requests will never reach the local server.

Disable the proxy, or add `*-local.hiclaw.io` / `127.0.0.1` to your proxy bypass list.

---

## How to talk to a Worker directly

After creating a Worker, Manager automatically adds you and the Worker to a shared group room. In that room, you must **@mention the Worker** for it to respond — messages without a mention are ignored.

When using Element or similar clients, type `@` followed by the first letter(s) of the Worker's display name to trigger autocomplete and select the right user.

Alternatively, you can click the Worker's avatar and open a **direct message** (DM) conversation. In a DM you don't need to @mention — every message triggers the Worker. Keep in mind that Manager is not in the DM room and won't see any of that conversation.

---

## How to switch the Manager's model

**Single provider**

In the Higress console, configure the `default-ai-route` route to point to your LLM provider. Then tell Manager the exact model name you want to use (e.g. `qwen3.5-plus`). Manager will run a connectivity test with that model name first — if it passes, the switch is applied automatically.

**Multiple providers**

In the Higress console, configure routing rules on `default-ai-route` so that different model name prefixes or regex patterns map to the corresponding provider. After that, the process is the same as the single-provider case — just tell Manager the model name and it handles the rest.

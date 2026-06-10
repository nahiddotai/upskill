#!/usr/bin/env python3
"""Upskill auto-sync MCP server.

Why this exists
---------------
The ideal way to keep synced skills current is the SessionStart hook
(`hooks/hooks.json`) — but some clients, notably the Claude desktop app, do not
dispatch plugin SessionStart hooks. Those same clients DO launch a plugin's MCP
servers at startup. So this server piggybacks on that launch to run a throttled,
best-effort refresh of the installed plugin. The result is a *general* auto-sync:
every skill becomes current with zero per-skill config and zero user action.

What it does
------------
1. On launch: kicks off `_auto_refresh.sh` (throttled ~4h, silent, non-blocking)
   so newly synced skills get pulled. This is the automatic path.
2. Exposes one tool, `upskill_resync`, to force an immediate refresh on demand.

Implementation notes
--------------------
Pure stdlib. Speaks MCP over stdio: newline-delimited JSON-RPC 2.0 messages.
It never writes anything but valid JSON-RPC to stdout, and never crashes on a
malformed message — a sync helper must not be able to break a session.
"""
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.normpath(os.path.join(HERE, "..", "skills", "upskill-sync", "scripts"))
AUTO_REFRESH = os.path.join(SCRIPTS, "_auto_refresh.sh")  # throttled, silent
REFRESH = os.path.join(SCRIPTS, "_refresh.sh")            # force, verbose

SERVER_NAME = "upskill-autosync"
SERVER_VERSION = "0.1.0"
DEFAULT_PROTOCOL = "2024-11-05"


def _augmented_env():
    """A PATH that lets the bundled refresh find claude/git/codex regardless of
    how sparse the launching client's environment is."""
    env = dict(os.environ)
    home = os.path.expanduser("~")
    extra = [os.path.join(home, ".local", "bin"), "/opt/homebrew/bin",
             "/opt/homebrew/sbin", "/usr/local/bin", "/usr/bin", "/bin"]
    parts = (env.get("PATH", "") or "").split(":")
    for p in extra:
        if p and p not in parts:
            parts.append(p)
    env["PATH"] = ":".join([p for p in parts if p])
    return env


def kickoff_startup_refresh():
    """Throttled, silent, NON-blocking refresh at launch (the automatic path)."""
    try:
        subprocess.Popen(
            ["bash", AUTO_REFRESH],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            stdin=subprocess.DEVNULL, env=_augmented_env(),
        )
    except Exception:
        pass  # best-effort; never block startup


def run_refresh_force(timeout=120):
    """Synchronous forced refresh for the upskill_resync tool."""
    try:
        cp = subprocess.run(
            ["bash", REFRESH], capture_output=True, text=True,
            timeout=timeout, env=_augmented_env(),
        )
        out = ((cp.stdout or "") + (cp.stderr or "")).strip()
        return cp.returncode == 0, out
    except subprocess.TimeoutExpired:
        return False, "Resync timed out after %ss." % timeout
    except Exception as e:  # pragma: no cover
        return False, "Resync error: %s" % e


TOOLS = [{
    "name": "upskill_resync",
    "description": ("Force an immediate Upskill sync: pull everyone's latest "
                    "skills into this client and refresh the installed plugin. "
                    "Use when the user wants new skills available right now "
                    "instead of waiting for the automatic throttled refresh."),
    "inputSchema": {"type": "object", "properties": {}, "additionalProperties": False},
}]


def _send(msg):
    sys.stdout.write(json.dumps(msg) + "\n")
    sys.stdout.flush()


def _reply(id_, result):
    _send({"jsonrpc": "2.0", "id": id_, "result": result})


def _reply_err(id_, code, message):
    _send({"jsonrpc": "2.0", "id": id_, "error": {"code": code, "message": message}})


def handle(msg):
    method = msg.get("method")
    id_ = msg.get("id")
    is_request = "id" in msg and id_ is not None

    if method == "initialize":
        proto = (msg.get("params") or {}).get("protocolVersion") or DEFAULT_PROTOCOL
        _reply(id_, {
            "protocolVersion": proto,
            "capabilities": {"tools": {}},
            "serverInfo": {"name": SERVER_NAME, "version": SERVER_VERSION},
        })
    elif method == "ping":
        _reply(id_, {})
    elif method == "tools/list":
        _reply(id_, {"tools": TOOLS})
    elif method == "tools/call":
        params = msg.get("params") or {}
        if params.get("name") == "upskill_resync":
            ok, out = run_refresh_force()
            text = out or ("Resync complete." if ok else "Resync failed.")
            _reply(id_, {"content": [{"type": "text", "text": text}], "isError": not ok})
        else:
            _reply_err(id_, -32602, "Unknown tool: %s" % params.get("name"))
    elif method == "resources/list":
        _reply(id_, {"resources": []})
    elif method == "prompts/list":
        _reply(id_, {"prompts": []})
    elif method and method.startswith("notifications/"):
        pass  # notifications never get a response
    elif is_request:
        _reply_err(id_, -32601, "Method not found: %s" % method)
    # else: a notification we don't recognize -> ignore


def main():
    kickoff_startup_refresh()
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except Exception:
            continue
        try:
            if isinstance(msg, list):       # JSON-RPC batch
                for m in msg:
                    handle(m)
            else:
                handle(msg)
        except Exception:
            pass  # one bad message must never kill the server


if __name__ == "__main__":
    main()

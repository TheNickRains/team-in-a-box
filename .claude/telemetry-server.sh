#!/bin/bash
# Serves ~/.claude/telemetry.jsonl at localhost:9847
# Run this, then open telemetry.html — it auto-loads.

PORT=9847
FILE="$HOME/.claude/telemetry.jsonl"

if ! command -v python3 &>/dev/null; then
  echo "python3 required"
  exit 1
fi

if [ ! -f "$FILE" ]; then
  echo "No telemetry file at $FILE"
  exit 1
fi

echo "Serving telemetry at http://localhost:$PORT/telemetry.jsonl"
echo "Open .claude/telemetry.html in browser"
echo "Press Ctrl+C to stop"
echo ""

cd "$HOME/.claude"
python3 -c "
import http.server
import socketserver

class CORSHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        super().end_headers()

with socketserver.TCPServer(('', $PORT), CORSHandler) as httpd:
    httpd.serve_forever()
"

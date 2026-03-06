Cancel a running cletus-loop by name.

Usage: /cletus-loop:cancel <name>

Execute the cancel by running:

```bash
PID_FILE="/tmp/cletus-loop/$ARGUMENTS.pid"
if [ -f "$PID_FILE" ]; then
  PID=$(cat "$PID_FILE")
  kill "$PID" 2>/dev/null && echo "Killed cletus-loop '$ARGUMENTS' (PID $PID)" || echo "Process $PID not running"
  rm -f "$PID_FILE"
else
  echo "No cletus-loop named '$ARGUMENTS' found"
fi
```

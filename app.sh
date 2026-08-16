#!/bin/bash

# Navigate to the directory where this script is located
cd "$(dirname "$0")"

# --- BACKEND SETUP ---
if [ ! -d ".venv" ]; then
    echo "First time setup: Finding compatible Python version (3.10 to 3.12)..."
    
    BEST_PYTHON=""
    for py in python3.12 python3.11 python3.10 python3; do
        if command -v "$py" >/dev/null 2>&1; then
            version=$("$py" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
            major=$(echo $version | cut -d. -f1)
            minor=$(echo $version | cut -d. -f2)
            if [ "$major" -eq 3 ] && [ "$minor" -ge 10 ] && [ "$minor" -le 12 ]; then
                BEST_PYTHON="$py"
                break
            fi
        fi
    done

    if [ -z "$BEST_PYTHON" ]; then
        echo "ERROR: Could not find Python 3.10, 3.11, or 3.12 installed on your system."
        echo "CadQuery requires one of these versions. Please install Python 3.12 and try again."
        exit 1
    fi

    echo "Using $BEST_PYTHON to create virtual environment..."
    "$BEST_PYTHON" -m venv .venv
    
    echo "Installing backend requirements. This might take a minute..."
    source .venv/bin/activate
    if ! pip install -r requirements.txt; then
        echo "ERROR: Failed to install Python dependencies. Please check the logs above."
        exit 1
    fi
else
    source .venv/bin/activate
fi

# Double check the venv actually works before starting. A venv that was created
# under a different path (e.g. the project folder was moved or renamed) still has
# all its files, but every script inside it points at an interpreter that no
# longer exists — so test that the interpreter runs and uvicorn imports.
if ! .venv/bin/python -c "import uvicorn" >/dev/null 2>&1; then
    echo "ERROR: The virtual environment is broken (its Python or uvicorn is unusable)."
    echo "This usually happens after moving or renaming the project folder."
    echo "Please run: rm -rf .venv && ./app.sh"
    exit 1
fi

echo "Starting FastAPI backend..."
# Invoke via 'python -m' rather than .venv/bin/uvicorn so the hardcoded shebang
# inside the console script can never break this.
nohup .venv/bin/python -m uvicorn api:app --reload > backend.log 2>&1 &
echo $! > .backend.pid

# Wait for the backend to actually come up; otherwise the frontend proxy just
# returns 500s and the real error stays buried in backend.log.
for _ in $(seq 1 30); do
    if curl -fsS http://127.0.0.1:8000/openapi.json >/dev/null 2>&1; then
        break
    fi
    sleep 1
done
if ! curl -fsS http://127.0.0.1:8000/openapi.json >/dev/null 2>&1; then
    echo "ERROR: Backend failed to start. Last lines of backend.log:"
    tail -20 backend.log
    exit 1
fi

# --- FRONTEND SETUP ---
cd frontend
if [ ! -d "node_modules" ]; then
    echo "First time setup: Installing frontend dependencies..."
    if ! npm install; then
        echo "ERROR: Failed to install frontend dependencies."
        exit 1
    fi
fi

echo "Starting Vite frontend..."
nohup npm run dev > frontend.log 2>&1 &
echo $! > ../.frontend.pid

echo ""
echo "Both servers are running in the background!"
echo "Backend is available at http://127.0.0.1:8000"
echo "Frontend is available at http://localhost:5173"
echo "To stop them, run: ./stop.sh"

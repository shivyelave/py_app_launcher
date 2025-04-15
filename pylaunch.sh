#!/bin/bash

# -------------------- USER INPUTS ---------------------
project_name="IC4-RegistrationPortal-API-dev"         # e.g., myapp
project_path="https://github.com/GathiAnalytics/IC4-RegistrationPortal-API.git"         # Git URL or local path
ssh_host=""             # e.g., user@1.2.3.4 OR empty for local
main_file=""            # Optional: file to run for Flask/Streamlit

# ------------------- HELPER FUNCS ---------------------
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }
fail() { log "❌ $1"; exit 1; }

is_git_url() {
  [[ "$project_path" =~ ^https?://.*\.git$ ]]
}

run_remote() {
  log "🌐 Running on remote VM: $ssh_host"
  scp "$0" "$ssh_host:/tmp/auto_deploy.sh"
  ssh "$ssh_host" "bash /tmp/auto_deploy.sh $project_name $project_path '' $main_file"
  exit 0
}

# ----------------- SSH or LOCAL -----------------------
if [ -n "$ssh_host" ]; then
  run_remote
else
  log "🖥️ Running deployment locally"
fi

# ----------------- PREP PROJECT DIR -------------------
rm -rf "$project_name"
mkdir "$project_name" || fail "Failed to create project directory"
cd "$project_name" || fail "Cannot enter project directory"

# ----------------- GET PROJECT CODE -------------------
if is_git_url; then
  log "🔄 Cloning from Git: $project_path"
  git clone "$project_path" . || fail "Git clone failed"
else
  log "📁 Copying files from local path: $project_path"
  cp -r "$project_path"/* . || fail "Copy failed"
fi

# ------------- CREATE & ACTIVATE VENV -----------------
# ----------- OS DETECTION (Linux, Mac, Windows) -------------
OS_TYPE="$(uname -s)"

case "$OS_TYPE" in
  Linux*)   PLATFORM="linux";;
  Darwin*)  PLATFORM="mac";;
  CYGWIN*|MINGW*|MSYS*) PLATFORM="windows";;
  *)        PLATFORM="unknown";;
esac

log "🧠 Detected platform: $PLATFORM"

# ---------- PYTHON & VENV PATHS BASED ON OS ----------------
if [ "$PLATFORM" == "windows" ]; then
  PYTHON_CMD="python"
  ACTIVATE_CMD="./venvv/Scripts/activate"
else
  PYTHON_CMD="python3"
  ACTIVATE_CMD="./venvv/Scripts/activate"
fi

# -------- CREATE & ACTIVATE VIRTUAL ENV ---------------------
log "🐍 Creating virtual environment..."
$PYTHON_CMD -m venv venvv || fail "Virtualenv creation failed"

log "⚡ Activating virtual environment..."
eval "$ACTIVATE_CMD" || fail "Virtualenv activation failed"
log "✅ Virtual environment activated"

# ----------------- INSTALL DEPENDENCIES ---------------
if [ -f requirements.txt ]; then
  log "📦 Installing from requirements.txt..."
  pip install --upgrade pip
  pip install -r requirements.txt || fail "Dependency install failed"
else
  log "⚠️ No requirements.txt found. Generating one..."
  pip freeze > requirements.txt
fi

# ------------------- DETECT APP TYPE ------------------
log "🔍 Detecting app framework..."
log "📜 Listing all files in the directory..."
ls -al || fail "Failed to list files"

log "📜 Checking for main file..."
if grep -qi streamlit requirements.txt && [ -n "$main_file" ]; then
  app_type="streamlit"
elif grep -qi flask requirements.txt && [ -n "$main_file" ]; then
  app_type="flask"
elif [ -f "manage.py" ]; then
  app_type="django"
else
  fail "❌ Unable to detect app type or missing main file."
fi

# ------------------- RUN APP --------------------------
log "🚀 Starting $app_type app..."

case "$app_type" in
  streamlit)
    streamlit run "$main_file"  --server.address 0.0.0.0 --server.port 8501|| fail "Streamlit failed to start"
    ;;
  flask)
    export FLASK_APP="$main_file"
    flask run --host=0.0.0.0 --port=5000 || fail "Flask failed to start"
    ;;
  django)
    python manage.py runserver 0.0.0.0:8000 || fail "Django failed to start"
    ;;
esac

#!/bin/bash

# -------------------- USER INPUTS ---------------------
usage() {
  echo "Usage: $0 --project_name <project_name> --project_path <project_path> [--ssh_host <ssh_host>] [--main_file <main_file>] [--branch_name <branch_name>]"
  echo ""
  echo "Parameters:"
  echo "  --project_name    Name of the project. Mandatory."
  echo "  --project_path    Path to project code or Git URL. Mandatory."
  echo "  --ssh_host        SSH host for remote deployment. Optional."
  echo "  --main_file       Main file to run the app. Optional for some app types."
  echo "  --branch_name     Git branch name (default: main). Optional."
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help)
      usage
      exit 0
      ;;
    --project_name)
      project_name="$2"
      shift 2
      ;;
    --project_path)
      project_path="$2"
      shift 2
      ;;
    --ssh_host)
      ssh_host="$2"
      shift 2
      ;;
    --main_file)
      main_file="$2"
      shift 2
      ;;
    --branch_name)
      branch_name="$2"
      shift 2
      ;;
    *)
      echo "Unknown parameter: $1"
      usage
      exit 1
      ;;
  esac
done

# Validate mandatory parameters
if [ -z "$project_name" ]; then
  echo "Error: --project_name is mandatory."
  usage
  exit 1
fi

if [ -z "$project_path" ]; then
  echo "Error: --project_path is mandatory."
  usage
  exit 1
fi

# Fallback defaults if parameters are not provided
: "${project_name:=}"
: "${project_path:=}"
: "${ssh_host:=}"
: "${main_file:=}"
: "${branch_name:=main}"

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
  if [ -n "$branch_name" ]; then
    log "🔄 Cloning from Git: $project_path (branch: $branch_name)"
    git clone "$project_path" -b "$branch_name" . || fail "Git clone failed"
  else
    log "🔄 Cloning from Git: $project_path"
    git clone "$project_path" . || fail "Git clone failed"
  fi
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

#-------------------Migrations---------------------
log "🔄 Checking for migrations..."
if [ "$app_type" = "django" ]; then
  log "🔄 Applying Django migrations..."
  python manage.py migrate || fail "Django migrations failed"
elif [ "$app_type" = "flask" ]; then
  if [ -d "migrations" ]; then
    log "🔄 Applying Flask migrations..."
    flask db upgrade || fail "Flask migrations failed"
  else
    log "⚠️ No migration directory found for Flask. Skipping migrations."
  fi
fi

# ------------------- RUN APP --------------------------
log "🚀 Starting $app_type app..."

# Determine host binding based on ssh_host parameter
if [ -n "$ssh_host" ]; then
  HOST="0.0.0.0"
else
  HOST="127.0.0.1"
fi

# Run the application based on the detected app type
case "$app_type" in
  streamlit)
    streamlit run "$main_file" --server.address "$HOST" --server.port 8501 || fail "Streamlit failed to start"
    ;;
  flask)
    export FLASK_APP="$main_file"
    flask run --host="$HOST" --port=5000 || fail "Flask failed to start"
    ;;
  django)
    python manage.py runserver "$HOST":8000 || fail "Django failed to start"
    ;;
esac

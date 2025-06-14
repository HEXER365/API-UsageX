#!/bin/bash

APP_DIR="/root"
REPO_URL="https://github.com/HEXER365/API-UsageX.git"
CLONE_DIR="$APP_DIR/API-UsageX"
VENV_DIR="$APP_DIR/myenv"
APP_FILE="$APP_DIR/api.py"
ENV_FILE="$APP_DIR/.env"
REQUIREMENTS_FILE="$APP_DIR/requirements.txt"
SERVICE_NAME="api"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"

log() {
  echo -e "\033[1;32m[INFO]\033[0m $1"
}

err() {
  echo -e "\033[1;31m[ERROR]\033[0m $1"
  exit 1
}

# Check for Python3
if ! command -v python3 &> /dev/null; then
  err "Python3 is not installed. Please install Python3 and try again."
fi

# Clone repo if not already cloned
if [ ! -d "$CLONE_DIR" ]; then
  log "Cloning repository from $REPO_URL..."
  git clone "$REPO_URL" "$CLONE_DIR" || err "Failed to clone repository."
else
  log "Repository already cloned at $CLONE_DIR."
fi

# Move files excluding .git
log "Moving files from $CLONE_DIR to $APP_DIR..."
shopt -s extglob nullglob dotglob
files=("$CLONE_DIR"/!(".git"))
if [ ${#files[@]} -gt 0 ]; then
  mv "${files[@]}" "$APP_DIR"
else
  err "No files to move from $CLONE_DIR."
fi
rm -rf "$CLONE_DIR"
log "Files moved successfully."

# Confirm requirements.txt exists
log "Listing files in $APP_DIR:"
ls -l "$APP_DIR"

# Create .env if missing
if [ ! -f "$ENV_FILE" ]; then
  echo ".env file not found. Let's create it."
  read -p "Enter full path to your SSL fullchain certificate (.pem): " ssl_cert
  read -p "Enter full path to your SSL private key (.key): " ssl_key

  echo "Creating .env file at $ENV_FILE..."
  cat > "$ENV_FILE" <<EOF
SSL_CERT_PATH=$ssl_cert
SSL_KEY_PATH=$ssl_key
EOF
else
  log ".env file already exists at $ENV_FILE. Skipping creation."
fi

# Create virtual environment
if [ ! -d "$VENV_DIR" ]; then
  log "Creating Python virtual environment at $VENV_DIR..."
  python3 -m venv "$VENV_DIR" || err "Failed to create virtual environment."
  log "Virtual environment created."
else
  log "Virtual environment already exists."
fi

# Verify venv python exists
if [ ! -x "$VENV_DIR/bin/python" ]; then
  err "Python not found in $VENV_DIR/bin/python. Virtual environment is broken."
fi

# Install dependencies
if [ -f "$REQUIREMENTS_FILE" ]; then
  log "Installing Python dependencies from $REQUIREMENTS_FILE..."
  "$VENV_DIR/bin/python" -m pip install --upgrade pip || err "Failed to upgrade pip."
  "$VENV_DIR/bin/pip" install -r "$REQUIREMENTS_FILE" || err "Failed to install requirements."
else
  log "No requirements.txt found at $REQUIREMENTS_FILE. Skipping dependency installation."
fi

# Create systemd service
log "Creating systemd service file at $SERVICE_FILE..."
sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=Flask API Service
After=network.target

[Service]
User=root
Group=root
WorkingDirectory=$APP_DIR
Environment=PATH=$VENV_DIR/bin
EnvironmentFile=$ENV_FILE
Environment=FLASK_ENV=production
Environment=PYTHONUNBUFFERED=1
ExecStart=$VENV_DIR/bin/python $APP_FILE
StandardOutput=journal
StandardError=journal
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOL

# Reload and start service
log "Reloading systemd daemon..."
sudo systemctl daemon-reload || err "Failed to reload systemd daemon."

log "Enabling and starting $SERVICE_NAME service..."
sudo systemctl enable $SERVICE_NAME || err "Failed to enable service."
sudo systemctl restart $SERVICE_NAME || err "Failed to start service."

log "✅ Service '$SERVICE_NAME' is now running."
echo "🔍 Check status: sudo systemctl status $SERVICE_NAME"
echo "📜 View logs:   sudo journalctl -u $SERVICE_NAME -f"

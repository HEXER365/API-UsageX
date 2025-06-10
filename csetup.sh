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

# Step 0: Clone repo if not already cloned
if [ ! -d "$CLONE_DIR" ]; then
  echo "Cloning repository from $REPO_URL..."
  git clone "$REPO_URL" "$CLONE_DIR"
else
  echo "Repository already cloned at $CLONE_DIR."
fi

# Step 0.5: Move files from clone dir to APP_DIR (excluding .git)
echo "Moving files from $CLONE_DIR to $APP_DIR..."
shopt -s dotglob
mv "$CLONE_DIR"/!(.git) "$APP_DIR"
rm -rf "$CLONE_DIR"
echo "Files moved."

# Step 1: Create .env file if not exists
if [ ! -f "$ENV_FILE" ]; then
  echo ".env file not found. Let's create it."
  read -p "Enter full path to your SSL fullchain certificate (.pem): " ssl_cert
  read -p "Enter full path to your SSL private key (.key): " ssl_key

  echo "Creating .env file at $ENV_FILE..."
  cat > "$ENV_FILE" <<EOF
SSL_CERT_PATH="$ssl_cert"
SSL_KEY_PATH="$ssl_key"
EOF
else
  echo ".env file already exists at $ENV_FILE. Skipping creation."
fi

# Step 2: Create virtual environment if it doesn't exist
if [ ! -d "$VENV_DIR" ]; then
  echo "Virtual environment not found at $VENV_DIR. Creating it..."
  python3 -m venv "$VENV_DIR"
  echo "Virtual environment created."
else
  echo "Virtual environment already exists at $VENV_DIR."
fi

# Step 3: Install Python dependencies if requirements.txt exists
if [ -f "$REQUIREMENTS_FILE" ]; then
  echo "Installing Python dependencies from $REQUIREMENTS_FILE..."
  source "$VENV_DIR/bin/activate"
  python -m pip install --upgrade pip
  pip install -r "$REQUIREMENTS_FILE"
  deactivate
else
  echo "No requirements.txt found at $REQUIREMENTS_FILE. Skipping dependency installation."
fi

# Step 4: Create systemd service file
echo "Creating systemd service file for Flask app..."

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

# Step 5: Reload systemd and start service
echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

echo "Enabling and starting $SERVICE_NAME service..."
sudo systemctl enable $SERVICE_NAME
sudo systemctl start $SERVICE_NAME

echo "✅ Service $SERVICE_NAME started."
echo "ℹ️  Check status with: sudo systemctl status $SERVICE_NAME"
echo "📜 View logs with: sudo journalctl -u $SERVICE_NAME -f"

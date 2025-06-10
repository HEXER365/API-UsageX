#!/bin/bash

APP_DIR="/root"
VENV_DIR="$APP_DIR/myenv"
APP_FILE="$APP_DIR/api.py"
ENV_FILE="$APP_DIR/.env"
REQUIREMENTS_FILE="$APP_DIR/requirements.txt"
SERVICE_NAME="api"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"

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

# Step 2: Install Python dependencies if requirements.txt exists
if [ -f "$REQUIREMENTS_FILE" ]; then
  echo "Installing Python dependencies from $REQUIREMENTS_FILE..."
  source "$VENV_DIR/bin/activate"
  pip install --upgrade pip
  pip install -r "$REQUIREMENTS_FILE"
  deactivate
else
  echo "No requirements.txt found at $REQUIREMENTS_FILE. Skipping dependency installation."
fi

# Step 3: Create systemd service file
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

# Step 4: Reload systemd and start service
echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

echo "Enabling and starting $SERVICE_NAME service..."
sudo systemctl enable $SERVICE_NAME
sudo systemctl start $SERVICE_NAME

echo "✅ Service $SERVICE_NAME started."
echo "ℹ️  Check status with: sudo systemctl status $SERVICE_NAME"
echo "📜 View logs with: sudo journalctl -u $SERVICE_NAME -f"

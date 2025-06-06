from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
import sqlite3
from datetime import datetime
import json
import os
from dotenv import load_dotenv  # import dotenv

app = Flask(__name__, static_folder='web')
CORS(app)

DATABASE = "/etc/x-ui/x-ui.db"
SPECIAL_EPOCH_STR = "1970-01-01T07:00:00"
SPECIAL_EPOCH_DATETIME = datetime.strptime(SPECIAL_EPOCH_STR, "%Y-%m-%dT%H:%M:%S")

# Load environment variables from .env
load_dotenv()

SSL_CERT_PATH = os.getenv("SSL_CERT_PATH")
SSL_KEY_PATH = os.getenv("SSL_KEY_PATH")

# Serve frontend files
@app.route('/')
def index():
    return send_from_directory('web', 'index.html')

@app.route('/<path:path>')
def static_files(path):
    return send_from_directory('web', path)

# Get client info from DB
def get_client_data(username):
    try:
        conn = sqlite3.connect(DATABASE)
        cursor = conn.cursor()

        cursor.execute("""
            SELECT email, up, down, total, expiry_time 
            FROM client_traffics 
            WHERE email = ?
        """, (username,))
        
        client = cursor.fetchone()
        conn.close()

        if client:
            raw_expiry = client[4]
            expiry_ts = raw_expiry if raw_expiry > 10**10 else raw_expiry * 1000
            expiry_datetime = datetime.fromtimestamp(expiry_ts / 1000)
            is_special_epoch = expiry_datetime == SPECIAL_EPOCH_DATETIME
            is_active = is_special_epoch or datetime.now() < expiry_datetime

            return {
                "username": client[0],
                "upload_bytes": client[1],
                "download_bytes": client[2],
                "total_bytes": client[3],
                "upload_gb": round(client[1] / (1024 ** 3), 2),
                "download_gb": round(client[2] / (1024 ** 3), 2),
                "total_gb": round(client[3] / (1024 ** 3), 2),
                "expiry_time": expiry_datetime.isoformat(),
                "status": "active" if is_active else "expired"
            }

        return None

    except sqlite3.Error as e:
        print(f"[DB ERROR] {e}")
        return None

# API endpoint
@app.route("/api/client", methods=["GET"])
def api_client():
    username = request.args.get("username")
    if not username:
        return jsonify({"status": "error", "message": "Username is required"}), 400

    print(f"[INFO] Username lookup: {username}")
    data = get_client_data(username)

    if data:
        result = {"status": "success", "data": data}
        print(json.dumps(result, indent=4))
        return jsonify(result)
    else:
        return jsonify({"status": "error", "message": "Client not found"}), 404


# Run with SSL using paths from .env
if __name__ == "__main__":
    if not SSL_CERT_PATH or not SSL_KEY_PATH:
        print("Error: SSL_CERT_PATH or SSL_KEY_PATH not set in .env file")
        exit(1)

    app.run(host="0.0.0.0", port=8000, ssl_context=(SSL_CERT_PATH, SSL_KEY_PATH))

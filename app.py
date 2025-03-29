import os
from flask import Flask, render_template, jsonify
import sqlite3
from datetime import datetime, timedelta
from flask_talisman import Talisman
from dotenv import load_dotenv
import logging

# Load environment variables
load_dotenv()

app = Flask(__name__)

# Security headers with Flask-Talisman
Talisman(app, content_security_policy=None)

# Database path (use environment variable for production)
DB_PATH = os.getenv("DB_PATH", "/etc/x-ui/x-ui.db")

# Logging configuration
logging.basicConfig(level=logging.INFO)

def get_traffic_data():
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()

        # Get current date and yesterday's date
        today = datetime.now().date()
        yesterday = today - timedelta(days=1)

        # Query total usage
        cursor.execute("SELECT SUM(total) FROM outbound_traffics;")
        total_usage = cursor.fetchone()[0] or 0  # Default to 0 if no data

        # Query daily usage for today
        cursor.execute(f"""
            SELECT SUM(total) 
            FROM outbound_traffics 
            WHERE DATE(timestamp) = '{today}';
        """)
        daily_usage = cursor.fetchone()[0] or 0

        # Query daily usage for yesterday
        cursor.execute(f"""
            SELECT SUM(total) 
            FROM outbound_traffics 
            WHERE DATE(timestamp) = '{yesterday}';
        """)
        yesterday_usage = cursor.fetchone()[0] or 0

        # Convert bytes to GB
        total_usage_gb = total_usage / (1024 ** 3)
        daily_usage_gb = daily_usage / (1024 ** 3)
        yesterday_usage_gb = yesterday_usage / (1024 ** 3)

        return {
            "total_usage_gb": round(total_usage_gb, 2),
            "daily_usage_gb": round(daily_usage_gb, 2),
            "yesterday_usage_gb": round(yesterday_usage_gb, 2),
        }
    except Exception as e:
        app.logger.error(f"Database error: {e}")
        return {"error": "Failed to fetch traffic data."}
    finally:
        if 'conn' in locals():
            conn.close()

@app.route("/")
def index():
    return render_template("index.html")

@app.route("/data")
def data():
    return jsonify(get_traffic_data())

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)

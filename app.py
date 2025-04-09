import os
from flask import Flask, render_template, jsonify
import sqlite3
from datetime import datetime, timedelta
from pytz import timezone
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Initialize Flask app
app = Flask(__name__)

# Get database path from environment variable
DB_PATH = os.getenv("DB_PATH", "/etc/x-ui/x-ui.db")

# Set local time zone (Asia/Tehran)
LOCAL_TIMEZONE = timezone("Asia/Tehran")

def get_traffic_data():
    """
    Fetch traffic data from the SQLite database.
    """
    try:
        # Connect to the database
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()

        # Query total usage, upload, and download
        cursor.execute("SELECT SUM(total), SUM(up), SUM(down) FROM outbound_traffics;")
        result = cursor.fetchone()
        total_usage = result[0] or 0  # Default to 0 if no data
        upload_usage = result[1] or 0
        download_usage = result[2] or 0

        # Get current date and yesterday's date in local time zone
        now = datetime.now(LOCAL_TIMEZONE)
        today = now.date()
        yesterday = today - timedelta(days=1)

        # Query daily usage for today
        cursor.execute(
            "SELECT SUM(total) FROM outbound_traffics WHERE DATE(timestamp) = ?;",
            (today,)
        )
        daily_usage = cursor.fetchone()[0] or 0

        # Query daily usage for yesterday
        cursor.execute(
            "SELECT SUM(total) FROM outbound_traffics WHERE DATE(timestamp) = ?;",
            (yesterday,)
        )
        yesterday_usage = cursor.fetchone()[0] or 0

        # Convert bytes to GB
        total_usage_gb = total_usage / (1024 ** 3)
        daily_usage_gb = daily_usage / (1024 ** 3)
        yesterday_usage_gb = yesterday_usage / (1024 ** 3)
        upload_usage_gb = upload_usage / (1024 ** 3)
        download_usage_gb = download_usage / (1024 ** 3)

        return {
            "total_usage_gb": round(total_usage_gb, 2),
            "daily_usage_gb": round(daily_usage_gb, 2),
            "yesterday_usage_gb": round(yesterday_usage_gb, 2),
            "upload_usage_gb": round(upload_usage_gb, 2),
            "download_usage_gb": round(download_usage_gb, 2),
        }

    except sqlite3.Error as e:
        app.logger.error(f"Database error: {e}")
        return {"error": "Database error. Check logs for details."}, 500

    except Exception as e:
        app.logger.error(f"Unexpected error: {e}")
        return {"error": "An unexpected error occurred. Check logs for details."}, 500

    finally:
        if 'conn' in locals() and conn:
            conn.close()

@app.route("/")
def index():
    """
    Render the main HTML page.
    """
    return render_template("index.html")

@app.route("/data")
def data():
    """
    API endpoint to fetch traffic data.
    """
    traffic_data = get_traffic_data()
    return jsonify(traffic_data)

if __name__ == "__main__":
    # Run the app in debug mode only for development
    app.run(host="0.0.0.0", port=9000, debug=False)

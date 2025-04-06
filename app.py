import os
from flask import Flask, render_template, jsonify
import sqlite3
from datetime import datetime, timedelta
from flask_talisman import Talisman
from dotenv import load_dotenv
import logging

# Load environment variables
load_dotenv()

# Initialize Flask app
app = Flask(__name__)

# Security headers with Flask-Talisman
Talisman(app, content_security_policy=None)

# Database path (use environment variable for production)
DB_PATH = os.getenv("DB_PATH", "/etc/x-ui/x-ui.db")

# Logging configuration
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def get_traffic_data():
    """
    Fetch traffic data from the SQLite database.
    """
    try:
        # Connect to the database
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

    except sqlite3.Error as e:
        logger.error(f"Database error: {e}")
        return {"error": "Database error. Check logs for details."}

    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return {"error": "An unexpected error occurred. Check logs for details."}

    finally:
        if 'conn' in locals() and conn:
            conn.close()

@app.route("/")
def index():
    """
    Render the main HTML page.
    """
    try:
        return render_template("index.html")
    except Exception as e:
        logger.error(f"Error rendering index.html: {e}")
        return "An error occurred while loading the page. Please check the logs.", 500

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

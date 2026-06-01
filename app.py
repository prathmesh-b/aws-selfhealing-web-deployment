import os
from flask import Flask, render_template_string
import psycopg2

app = Flask(__name__)

DB_HOST = os.environ.get('DB_HOST')
DB_USER = os.environ.get('DB_USER')
DB_PASSWORD = os.environ.get('DB_PASSWORD')
DB_NAME = os.environ.get('DB_NAME', 'postgres')

def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST, user=DB_USER, password=DB_PASSWORD, database=DB_NAME, connect_timeout=3
    )

@app.route('/')
def index():
    status = "Disconnected"
    db_records = []
    error_msg = ""
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("""
            CREATE TABLE IF NOT EXISTS system_logs (
                id SERIAL PRIMARY KEY,
                hit_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """)
        cur.execute("INSERT INTO system_logs DEFAULT VALUES;")
        conn.commit()
        cur.execute("SELECT id, hit_time FROM system_logs ORDER BY id DESC LIMIT 5;")
        db_records = cur.fetchall()
        cur.close()
        conn.close()
        status = "Connected Successfully!"
    except Exception as e:
        status = "Connection Failed"
        error_msg = str(e)

    html_template = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Flask/Postgresql app by Prathmesh-b</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; background-color: #f4f6f9; color: #333; }
            .card { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
            .status { font-weight: bold; padding: 8px; border-radius: 4px; display: inline-block; }
            .success { background-color: #d4edda; color: #155724; }
            .danger { background-color: #f8d7da; color: #721c24; }
            ul { background: #eee; padding: 15px 30px; border-radius: 4px; }
        </style>
    </head>
    <body>
        <div class="card">
            <h1>Automated Web App Deployment System</h1>
            <p><strong>Database Status:</strong> <span class="status {{ 'success' if 'Successfully' in status else 'danger' }}">{{ status }}</span></p>
            {% if error_msg %}<p style="color:red;"><strong>Error:</strong> {{ error_msg }}</p>{% endif %}
            <br></br>
            <h3>Recent DB Entries (Live from RDS):</h3>
            <ul>
            {% for row in db_records %}
                <li>Log Entry #{{ row[0] }} - Registered at: {{ row[1] }}</li>
            {% endfor %}
            </ul>
            <br></br>
            <p><b><i>Project built by Prathmesh-b</b></i></p>
        </div>
    </body>
    </html>
    """
    return render_template_string(html_template, status=status, db_records=db_records, error_msg=error_msg)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)

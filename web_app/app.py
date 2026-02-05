from flask import Flask, render_template, request, redirect, session, jsonify
import threading
import time
import psutil
import requests
import os

app = Flask(__name__)
app.secret_key = "secure-production-key"

load_running = False
load_threads = []

# ---------- CPU LOAD FUNCTION ----------
def cpu_stress():
    while load_running:
        pass

# ---------- METADATA (NO BOTO3) ----------
def get_metadata(path):
    try:
        return requests.get(
            f"http://169.254.169.254/latest/meta-data/{path}",
            timeout=2
        ).text
    except:
        return "N/A"

# ---------- LOGIN ----------
@app.route("/", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        emp_id = request.form.get("employee_id")

        if emp_id.isdigit() and 1 <= int(emp_id) <= 20:
            session["employee_id"] = emp_id.zfill(3)
            return redirect("/dashboard")
        else:
            return render_template("login.html", error="Employee ID must be between 001 and 020")

    return render_template("login.html")

# ---------- DASHBOARD ----------
@app.route("/dashboard")
def dashboard():
    if "employee_id" not in session:
        return redirect("/")

    data = {
        "employee_id": session["employee_id"],
        "instance_id": get_metadata("instance-id"),
        "instance_name": os.getenv("HOSTNAME", "EC2-Instance"),
        "subnet_id": get_metadata("network/interfaces/macs/").split("/")[0]
    }

    return render_template("dashboard.html", **data)

# ---------- START LOAD ----------
@app.route("/start-load", methods=["POST"])
def start_load():
    global load_running, load_threads

    if not load_running:
        load_running = True
        load_threads = []

        for _ in range(psutil.cpu_count()):
            t = threading.Thread(target=cpu_stress)
            t.daemon = True
            t.start()
            load_threads.append(t)

    return jsonify({"status": "CPU load started"})

# ---------- STOP LOAD ----------
@app.route("/stop-load", methods=["POST"])
def stop_load():
    global load_running
    load_running = False
    return jsonify({"status": "CPU load stopped"})

# ---------- CPU USAGE ----------
@app.route("/cpu")
def cpu():
    return jsonify({"cpu": psutil.cpu_percent(interval=1)})

# ---------- MAIN ----------
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)

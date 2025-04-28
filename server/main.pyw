from flask import Flask, request, jsonify, send_file
import pyautogui
import io
import socket
from flask_cors import CORS
from datetime import datetime

app = Flask(__name__)
CORS(app)

def get_ip_addresses():
    hostname = socket.gethostname()
    ip_list = []
    
    try:
        ip_list = socket.gethostbyname_ex(hostname)[2]
    except:
        pass
    
    if '127.0.0.1' not in ip_list:
        ip_list.append('127.0.0.1')
    
    return ip_list

def write_config():
    ip_addresses = get_ip_addresses()
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    with open('conf.txt', 'w') as f:
        f.write(f"Server started at: {timestamp}\n")
        f.write("Available IP addresses:\n")
        for ip in ip_addresses:
            f.write(f" * Running on http://{ip}:5000\n")

@app.route('/screenshot', methods=['GET'])
def screenshot():
    try:
        screenshot = pyautogui.screenshot()
        img_io = io.BytesIO()
        screenshot.save(img_io, 'JPEG', quality=80)
        img_io.seek(0)
        return send_file(img_io, mimetype='image/jpeg')
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/touch', methods=['POST'])
def touch():
    try:
        data = request.json
        x = int(data['x'])
        y = int(data['y'])
        
        x = max(0, min(x, pyautogui.size().width - 1))
        y = max(0, min(y, pyautogui.size().height - 1))
        
        pyautogui.moveTo(x, y)
        pyautogui.click()
        
        return jsonify({
            'status': 'success',
            'x': x,
            'y': y,
            'screen_size': {
                'width': pyautogui.size().width,
                'height': pyautogui.size().height
            }
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 400

if __name__ == '__main__':
    write_config()
    
    app.run(host='0.0.0.0', port=5000, threaded=True)
from flask import Flask, request, jsonify, send_file
import pyautogui
import io
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

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
        
        # Додамо невелику корекцію для компенсації затримки
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
    app.run(host='0.0.0.0', port=5000, threaded=True)
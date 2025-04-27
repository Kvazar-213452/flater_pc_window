from flask import Flask, request, send_file
import pyautogui
import io
from flask_cors import CORS  # Імпортуємо CORS

app = Flask(__name__)
CORS(app)  # Додаємо CORS для всіх маршрутів

@app.route('/screenshot', methods=['GET'])
def screenshot():
    screenshot = pyautogui.screenshot()
    img_io = io.BytesIO()
    screenshot.save(img_io, 'JPEG', quality=30)
    img_io.seek(0)
    return send_file(img_io, mimetype='image/jpeg')

@app.route('/touch', methods=['POST'])
def touch():
    data = request.json
    x = data.get('x')
    y = data.get('y')
    action = data.get('action')

    if action == "move":
        pyautogui.moveTo(x, y)
    elif action == "click":
        pyautogui.click(x, y)

    return {'status': 'ok'}

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)

from flask import Flask, request, jsonify
from flask_cors import CORS
import requests

app = Flask(__name__)
CORS(app)

@app.route('/api/claude', methods=['POST'])
def claude_proxy():
    data = request.json
    api_key = request.headers.get('X-Api-Key')
    
    response = requests.post(
        'https://api.anthropic.com/v1/messages',
        headers={
            'x-api-key': api_key,
            'anthropic-version': '2023-06-01',
            'content-type': 'application/json'
        },
        json=data
    )
    return jsonify(response.json())

if __name__ == '__main__':
    app.run(port=8080)
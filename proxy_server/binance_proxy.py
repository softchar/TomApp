"""
Binance API 代理服务器 (Python 版本)
用于在无法直接访问 Binance API 的地区使用

部署方式：
1. 安装依赖: pip install flask flask-cors requests
2. 运行: python binance_proxy.py
3. 或使用 Gunicorn: gunicorn -w 4 -b 0.0.0.0:3000 binance_proxy:app
"""

from flask import Flask, jsonify, request, Response
from flask_cors import CORS
import requests
from datetime import datetime

app = Flask(__name__)
CORS(app)

# Binance API 基础URL
BINANCE_API = 'https://fapi.binance.com'

@app.route('/')
def index():
    """根路径 - API信息"""
    return jsonify({
        'name': 'Binance API Proxy (Python)',
        'version': '1.0.0',
        'endpoints': {
            'health': '/health',
            'proxy': '/api/<path:path>'
        },
        'usage': {
            'example': f"{request.scheme}://{request.host}/api/fapi/v1/premiumIndex",
            'note': '所有 /api/* 的请求都会被代理到 Binance API'
        }
    })

@app.route('/health')
def health():
    """健康检查"""
    return jsonify({
        'status': 'ok',
        'timestamp': datetime.now().isoformat(),
        'binance_api': BINANCE_API
    })

@app.route('/api/<path:path>', methods=['GET', 'POST'])
def proxy(path):
    """代理请求到 Binance API"""
    try:
        # 构建目标 URL
        query_string = request.query_string.decode('utf-8')
        target_url = f"{BINANCE_API}/{path}"
        if query_string:
            target_url += f"?{query_string}"

        print(f"[{datetime.now().isoformat()}] 代理请求: {target_url}")

        # 转发请求到 Binance
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Accept': 'application/json',
        }

        # 根据请求方法选择
        if request.method == 'GET':
            resp = requests.get(target_url, headers=headers, timeout=30)
        else:
            resp = requests.post(target_url, headers=headers, json=request.get_json(), timeout=30)

        # 返回响应
        return Response(
            resp.content,
            status=resp.status_code,
            content_type='application/json',
            headers={'Access-Control-Allow-Origin': '*'}
        )

    except requests.exceptions.Timeout:
        return jsonify({'error': '请求超时', 'message': 'Binance API 响应超时'}), 408
    except requests.exceptions.RequestException as e:
        print(f"代理请求错误: {e}")
        return jsonify({'error': '代理请求失败', 'message': str(e)}), 500
    except Exception as e:
        print(f"服务器错误: {e}")
        return jsonify({'error': '服务器内部错误', 'message': str(e)}), 500

if __name__ == '__main__':
    PORT = 3000
    print("=" * 50)
    print("Binance API 代理服务器已启动 (Python)")
    print(f"端口: {PORT}")
    print(f"时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 50)
    print("使用方法:")
    print("在 Flutter 应用中设置:")
    print(f"BinanceApiService.setCustomBaseUrl('http://YOUR_SERVER_IP:{PORT}/api');")
    print("=" * 50)
    app.run(host='0.0.0.0', port=PORT, debug=False)

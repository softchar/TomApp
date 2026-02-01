# Binance API 代理服务器

用于在中国大陆等无法直接访问 Binance API 的地区使用。

## 部署方式

### 方案 1: VPS 服务器部署

1. 购买一台境外 VPS（推荐：腾讯云轻量应用服务器、阿里云香港、Vultr、DigitalOcean 等）

2. 选择 Node.js 版本：
```bash
# 安装依赖
npm install

# 启动服务
npm start

# 使用 PM2 守护进程（推荐）
npm install -g pm2
pm2 start binance_proxy.js --name binance-proxy
pm2 save
pm2 startup
```

3. 选择 Python 版本：
```bash
# 安装依赖
pip install flask flask-cors requests

# 启动服务
python binance_proxy.py

# 或使用 Gunicorn（推荐生产环境）
pip install gunicorn
gunicorn -w 4 -b 0.0.0.0:3000 binance_proxy:app
```

### 方案 2: 免费云服务部署

#### Railway
1. 访问 https://railway.app/
2. 连接 GitHub 仓库
3. Railway 会自动检测 Node.js 项目并部署
4. 部署完成后获得 HTTPS URL

#### Render
1. 访问 https://render.com/
2. 选择 "New + Web Service"
3. 连接 GitHub 仓库或上传代码
4. 设置构建和启动命令
5. 部署完成获得 URL

#### Vercel (需要修改适配)
```bash
# 创建 api/index.js
module.exports = require('./binance_proxy.js');
# 然后部署到 Vercel
```

### 方案 3: Cloudflare Workers (免费)

创建 `worker.js`:
```javascript
export default {
  async fetch(request) {
    const url = new URL(request.url);
    const path = url.pathname.replace('/api', '');
    const targetUrl = `https://fapi.binance.com${path}${url.search}`;

    const response = await fetch(targetUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0',
        'Accept': 'application/json',
      },
    });

    return new Response(response.body, {
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    });
  },
};
```

部署到 Cloudflare Workers 后获得的 URL 格式如：
`https://your-worker.your-subdomain.workers.dev`

## Flutter 配置

在应用启动时设置代理地址：

```dart
// main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 设置代理服务器地址
  BinanceApiService.setCustomBaseUrl('https://your-proxy-server.com/api');

  popupAlertService = PopupAlertService();
  await popupAlertService.initialize();
  runApp(const MyApp());
}
```

## 测试代理

部署后测试是否正常：

```bash
# 测试健康检查
curl http://your-server:3000/health

# 测试代理功能
curl http://your-server:3000/api/fapi/v1/premiumIndex?symbol=BTCUSDT
```

## 安全建议

1. 添加 API 密钥认证（在生产环境中）
2. 使用 HTTPS
3. 限制请求频率防止滥用
4. 添加访问日志

## 端口说明

默认端口：3000
确保你的服务器防火墙已开放该端口。

## 故障排查

1. 检查服务器防火墙设置
2. 确认 Binance API 可访问：`curl https://fapi.binance.com/fapi/v1/ping`
3. 查看代理服务器日志

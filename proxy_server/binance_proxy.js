/**
 * Binance API 代理服务器
 * 用于在无法直接访问 Binance API 的地区使用
 *
 * 部署方式：
 * 1. 安装依赖: npm install express cors
 * 2. 运行: node binance_proxy.js
 * 3. 或使用 PM2: pm2 start binance_proxy.js
 */

const express = require('express');
const cors = require('cors');
const https = require('https');
const url = require('url');

const app = express();
const PORT = process.env.PORT || 3000;

// 启用 CORS
app.use(cors());

// Binance API 基础URL
const BINANCE_API = 'https://fapi.binance.com';

/**
 * 代理请求到 Binance API
 */
app.get('/api/*', async (req, res) => {
  try {
    // 获取原始请求路径
    const requestPath = req.url.replace('/api', '');
    const targetUrl = BINANCE_API + requestPath;

    console.log(`[${new Date().toISOString()}] 代理请求: ${targetUrl}`);

    // 转发请求到 Binance
    const options = {
      method: 'GET',
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'application/json',
      },
    };

    const proxyReq = https.get(targetUrl, options, (proxyRes) => {
      // 设置响应头
      res.setHeader('Content-Type', 'application/json');
      res.setHeader('Access-Control-Allow-Origin', '*');

      // 转发状态码
      res.status(proxyRes.statusCode);

      // 转发数据
      proxyRes.pipe(res);
    });

    proxyReq.on('error', (err) => {
      console.error('代理请求错误:', err.message);
      res.status(500).json({
        error: '代理请求失败',
        message: err.message,
      });
    });

  } catch (error) {
    console.error('服务器错误:', error);
    res.status(500).json({
      error: '服务器内部错误',
      message: error.message,
    });
  }
});

// 健康检查端点
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    binance_api: BINANCE_API,
  });
});

// 根路径
app.get('/', (req, res) => {
  res.json({
    name: 'Binance API Proxy',
    version: '1.0.0',
    endpoints: {
      health: '/health',
      proxy: '/api/*',
    },
    usage: {
      example: `${req.protocol}://${req.get('host')}/api/fapi/v1/premiumIndex`,
      note: '所有 /api/* 的请求都会被代理到 Binance API',
    },
  });
});

// 启动服务器
app.listen(PORT, () => {
  console.log(`========================================`);
  console.log(`Binance API 代理服务器已启动`);
  console.log(`端口: ${PORT}`);
  console.log(`时间: ${new Date().toLocaleString('zh-CN')}`);
  console.log(`========================================`);
  console.log(`使用方法:`);
  console.log(`在 Flutter 应用中设置:`);
  console.log(`BinanceApiService.setCustomBaseUrl('http://YOUR_SERVER_IP:${PORT}/api');`);
  console.log(`========================================`);
});

module.exports = app;

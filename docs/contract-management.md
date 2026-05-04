# Contract Management Feature

## Overview
Automatically syncs Binance futures contract information to local SQLite database.

## Usage
1. Go to "我" (Profile) screen
2. Find "合约信息管理" section
3. Toggle "自动同步合约信息" to enable

## Data Storage
- Table: futures_symbols
- Sync frequency: Every hour
- Conflict resolution: INSERT OR REPLACE on symbol
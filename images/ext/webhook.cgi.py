#!/usr/bin/env python3
import cgi
import os
import requests  # 建议使用 requests 库发送 Webhook
import sys

# 设置响应头
print("Content-Type: text/html\n")

# 1. 获取上传文件
form = cgi.FieldStorage()
file_item = form['filename'] if 'filename' in form else None

if file_item and file_item.filename:
    # 获取文件名并安全处理
    fn = os.path.basename(file_item.filename)
    upload_path = os.path.join('/tmp', fn)

    # 2. 保存文件到本地
    with open(upload_path, 'wb') as f:
        f.write(file_item.file.read())

    # 3. 触发 Webhook (例如发送到企业微信、飞书或 Slack)
    webhook_url = "your-webhook-endpoint.com"
    payload = {
        "msgtype": "text",
        "text": {
            "content": f"文件上传成功！文件名：{fn}\n保存路径：{upload_path}"
        }
    }

    try:
        response = requests.post(webhook_url, json=payload, timeout=10)
        if response.status_code == 200:
            print("<h1>上传成功并已发送 Webhook 通知</h1>")
        else:
            print(f"<h1>上传成功，但 Webhook 发送失败 (状态码: {response.status_code})</h1>")
    except Exception as e:
        print(f"<h1>Webhook 调用异常: {str(e)}</h1>")
else:
    print("<h1>未选择文件或上传失败</h1>")

#!/usr/bin/env nu

# 1. 设置响应头 (CGI 标准)
print "Content-Type: application/json\n"

# 2. 读取上传内容 (假设为简单文件流或经过处理的二进制)
# 注意：在标准 CGI 中，环境变量如 $env.CONTENT_LENGTH 定义了数据长度
let content_length = ($env.CONTENT_LENGTH? | into int)
let raw_data = (read -n $content_length)

# 3. 保存文件到服务器
let upload_path = "/tmp/uploaded_file.dat"
$raw_data | save -f $upload_path


# # 4. 准备 Webhook 数据
# let webhook_url = "your-webhook-endpoint.com"
# let payload = {
#     event: "file_uploaded",
#     filename: "uploaded_file.dat",
#     size: ($raw_data | bytes length),
#     timestamp: (date now | format date "%Y-%m-%d %H:%M:%S")
# }

# # 5. 触发 Webhook
# try {
#     let response = (http post -t application/json $webhook_url $payload)
#     print { status: "success", webhook_response: $response } | to json
# } catch {
#     print { status: "error", message: "Webhook failed" } | to json
# }

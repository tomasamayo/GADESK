# Included inside exact account locations only.
proxy_pass http://127.0.0.1:21114;
proxy_http_version 1.1;
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $remote_addr;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_connect_timeout 5s;
proxy_read_timeout 30s;
proxy_cache off;
proxy_no_cache 1;
proxy_hide_header Cache-Control;
add_header Cache-Control "no-store" always;
add_header Referrer-Policy "no-referrer" always;
add_header Strict-Transport-Security "max-age=31536000" always;
client_max_body_size 10m;
limit_req_status 429;
error_page 429 = @gadesk_account_rate_limit;
# Callback and polling URLs contain one-use codes; keep them out of access logs.
access_log off;
error_log /dev/null;

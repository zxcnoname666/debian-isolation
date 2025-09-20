nohup mitmdump -s /home/dev/.init.d/mitm/url_rewriter.py --listen-port 8080 --set stream_large_bodies=10m --set keep_host_header=true >/dev/null 2>&1 &

#!/usr/bin/env python3


import http.server
import socketserver
import webbrowser
from pathlib import Path
import time
import threading

PORT = 8000

class MyHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):

        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate')
        super().end_headers()

    def log_message(self, format, *args):
      
        if args[1] != '200':
            super().log_message(format, *args)

def open_browser_delayed():
    time.sleep(1.5)
    webbrowser.open(f'http://localhost:{PORT}/houston_heatmap_click.html')

def main():
    script_dir = Path(__file__).parent
    import os
    os.chdir(script_dir)
    

    browser_thread = threading.Thread(target=open_browser_delayed, daemon=True)
    browser_thread.start()
    
    with socketserver.TCPServer(("", PORT), MyHTTPRequestHandler) as httpd:
        try:
            print(f"\n🚀 Server running at http://localhost:{PORT}/")
            print("   Opening browser...\n")
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n\n👋 Shutting down server...")
            httpd.shutdown()

if __name__ == '__main__':
    main()

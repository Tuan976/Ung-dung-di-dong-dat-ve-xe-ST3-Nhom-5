import psutil
for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
    if 'python' in proc.info['name'].lower():
        print(f"PID: {proc.info['pid']}, Cmd: {proc.info['cmdline']}")

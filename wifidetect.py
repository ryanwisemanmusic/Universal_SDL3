import time
import subprocess
import sqlite3
import os
import pandas as pd


def get_wifi_info():
    """Get WiFi info using /proc filesystem (works in Docker containers)"""
    info = {'status': 'disconnected'}
    
    try:
        if os.path.exists('/proc/net/wireless'):
            with open('/proc/net/wireless', 'r') as f:
                lines = f.readlines()
            
            for line in lines[2:]: 
                parts = line.strip().split()
                if len(parts) >= 3:
                    interface = parts[0].rstrip(':')
                    signal = parts[2]
                    
                    if signal != '0':
                        info.update({
                            'interface': interface,
                            'RSSI': signal,
                            'status': 'connected'
                        })
                        break
                        
        return info
        
    except Exception as e:
        print(f"Error getting WiFi info: {e}")
        return {'status': 'error', 'error': str(e)}

def test_pandas():
    """Test function to verify pandas is working"""
    try:
        # Create a simple DataFrame to test pandas functionality
        data = {'timestamp': [time.time()], 'status': ['connected']}
        df = pd.DataFrame(data)
        print("✓ Pandas is working correctly!")
        print(f"✓ DataFrame created: {df.to_dict()}")
        return df
    except Exception as e:
        print(f"✗ Pandas test failed: {e}")
        return None

if __name__ == "__main__":
    print("Testing WiFi detection and pandas integration...")
    wifi_info = get_wifi_info()
    if wifi_info:
        print("WiFi Info:", wifi_info)

    test_pandas()
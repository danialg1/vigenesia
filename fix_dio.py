import glob
import re

files = glob.glob('lib/Screens/*.dart') + glob.glob('lib/*.dart')

for f in files:
    with open(f, 'r', encoding='utf-8') as file:
        content = file.read()
    
    if 'var dio = Dio();' in content:
        new_content = content.replace(
            'var dio = Dio();',
            \"var dio = Dio(BaseOptions(headers: {'ngrok-skip-browser-warning': '69420'}));\"
        )
        with open(f, 'w', encoding='utf-8') as file:
            file.write(new_content)
        print(f"Updated {f}")

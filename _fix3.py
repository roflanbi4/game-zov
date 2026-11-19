import re

path = r'd:\Godot\.NET\Projects\east-rift-zone\scripts\ui\GameHUD.gd'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Pattern to match the soldiers declaration inside the flashlight if block
# We need to move it out

old = '\t\tvar soldiers: Array = squad.get("soldiers")\n\t\tif soldiers != null and soldiers.size() > 0 and is_instance_valid(soldiers[0]):'
new = '\tvar soldiers: Array = squad.get("soldiers")\n\tif soldiers != null and soldiers.size() > 0 and is_instance_valid(soldiers[0]):'

if old in content:
    content = content.replace(old, new, 1)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print('SUCCESS: moved soldiers declaration')
else:
    print('FAILED: pattern not found')
    idx = content.find('var soldiers: Array = squad.get("soldiers")')
    if idx >= 0:
        print(repr(content[idx:idx+100]))
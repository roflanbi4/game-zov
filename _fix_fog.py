import io

path = r'd:\Godot\.NET\Projects\east-rift-zone\scripts\core\FogOfWarManager.gd'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old = (
    '\t\t\tif is_night and rank == VeterancyComponent.Rank.ROOKIE and not has_nvg and flashlight_on:\n'
    '\t\t\t\tif flashlight_on:\n'
    '\t\t\t\t\tvar raw_dir: Variant = s.get("_last_facing")\n'
    '\t\t\t\t\tvar dir: Vector2 = Vector2.RIGHT\n'
    '\t\t\t\t\tif raw_dir is Vector2 and (raw_dir as Vector2).length() > 0.01:\n'
    '\t\t\t\t\t\tdir = (raw_dir as Vector2).normalized()\n'
    '\t\t\t\t\tsources.append({"pos": s.global_position, "radius": 320.0, "thermal": false, "cone": true, "dir": dir, "half_deg": 25.0})\n'
)

new = (
    '\t\t\tif is_night and rank == VeterancyComponent.Rank.ROOKIE and not has_nvg and flashlight_on:\n'
    '\t\t\t\tvar raw_dir: Variant = s.get("_last_facing")\n'
    '\t\t\t\tvar dir: Vector2 = Vector2.RIGHT\n'
    '\t\t\t\tif raw_dir is Vector2 and (raw_dir as Vector2).length() > 0.01:\n'
    '\t\t\t\t\tdir = (raw_dir as Vector2).normalized()\n'
    '\t\t\t\tsources.append({"pos": s.global_position, "radius": 320.0, "thermal": false, "cone": true, "dir": dir, "half_deg": 25.0})\n'
)

if old in content:
    content = content.replace(old, new, 1)
    with open(path, 'w', encoding='utf-8', newline='') as f:
        f.write(content)
    print('SUCCESS')
else:
    print('FAILED: pattern not found')
    idx = content.find('and not has_nvg and flashlight_on')
    print(repr(content[idx-30:idx+350]))

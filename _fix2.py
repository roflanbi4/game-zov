path = r'd:\Godot\.NET\Projects\east-rift-zone\scripts\ui\GameHUD.gd'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# The soldiers variable is declared inside the if block, so it's not accessible at the NVG/rankup scope.
# We need to move the NVG and rankup logic INSIDE the soldiers if block.
# Let's find the exact text and fix it.

old = '\tif _flashlight_btn != null and squad != null:\n\t\tvar soldiers: Array = squad.get("soldiers")\n\t\tif soldiers != null and soldiers.size() > 0 and is_instance_valid(soldiers[0]):\n\t\t\tvar on: bool = bool(soldiers[0].get("flashlight_on"))\n\t\t\t_flashlight_btn.text = "Фонарики: " + ("ВКЛ" if on else "ВЫКЛ")\n\n\t# ПНВ кнопка видима, если в отряде есть боец без ПНВ и не Veteran+\n\tif _nvg_btn != null:\n\t\tvar any_need_nvg: bool = false\n\t\tfor s in soldiers:\n\t\t\tif not is_instance_valid(s):\n\t\t\t\tcontinue\n\t\t\tvar vc: VeterancyComponent = s.get_node_or_null("VeterancyComponent") as VeterancyComponent\n\t\t\tvar rank: int = vc.rank if vc != null else VeterancyComponent.Rank.ROOKIE\n\t\t\tif not bool(s.get("has_nvg")) and rank < VeterancyComponent.Rank.VETERAN:\n\t\t\t\tany_need_nvg = true\n\t\t\t\tbreak\n\t\t_nvg_btn.visible = any_need_nvg\n\n\t# Кнопка повышения ранга видима, если не все Elite\n\tif _rankup_btn != null:\n\t\tvar all_elite: bool = true\n\t\tfor s in soldiers:\n\t\t\tif not is_instance_valid(s):\n\t\t\t\tcontinue\n\t\t\tvar vc: VeterancyComponent = s.get_node_or_null("VeterancyComponent") as VeterancyComponent\n\t\t\tif vc == null or vc.rank < VeterancyComponent.Rank.ELITE:\n\t\t\t\tall_elite = false\n\t\t\t\tbreak\n\t\t_rankup_btn.visible = not all_elite\n'

new = '\tvar soldiers: Array = []\n\tif squad != null:\n\t\tsoldiers = squad.get("soldiers")\n\tif _flashlight_btn != null and squad != null:\n\t\tif soldiers != null and soldiers.size() > 0 and is_instance_valid(soldiers[0]):\n\t\t\tvar on: bool = bool(soldiers[0].get("flashlight_on"))\n\t\t\t_flashlight_btn.text = "Фонарики: " + ("ВКЛ" if on else "ВЫКЛ")\n\n\t# ПНВ кнопка видима, если в отряде есть боец без ПНВ и не Veteran+\n\tif _nvg_btn != null and soldiers != null:\n\t\tvar any_need_nvg: bool = false\n\t\tfor s in soldiers:\n\t\t\tif not is_instance_valid(s):\n\t\t\t\tcontinue\n\t\t\tvar vc: VeterancyComponent = s.get_node_or_null("VeterancyComponent") as VeterancyComponent\n\t\t\tvar rank: int = vc.rank if vc != null else VeterancyComponent.Rank.ROOKIE\n\t\t\tif not bool(s.get("has_nvg")) and rank < VeterancyComponent.Rank.VETERAN:\n\t\t\t\tany_need_nvg = true\n\t\t\t\tbreak\n\t\t_nvg_btn.visible = any_need_nvg\n\n\t# Кнопка повышения ранга видима, если не все Elite\n\tif _rankup_btn != null and soldiers != null:\n\t\tvar all_elite: bool = true\n\t\tfor s in soldiers:\n\t\t\tif not is_instance_valid(s):\n\t\t\t\tcontinue\n\t\t\tvar vc: VeterancyComponent = s.get_node_or_null("VeterancyComponent") as VeterancyComponent\n\t\t\tif vc == null or vc.rank < VeterancyComponent.Rank.ELITE:\n\t\t\t\tall_elite = false\n\t\t\t\tbreak\n\t\t_rankup_btn.visible = not all_elite\n'

if old in content:
    content = content.replace(old, new, 1)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print('SUCCESS')
else:
    print('FAILED')
    idx = content.find('\tif _flashlight_btn != null')
    if idx >= 0:
        print(repr(content[idx:idx+600]))
    else:
        print('not found')

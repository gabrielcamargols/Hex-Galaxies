"""Monta o preset "Vozes" (pacote separado só com as falas dos personagens v_*) e tira as falas
do pacote principal da web. O jogo baixa vozes.pck em segundo plano depois de abrir.
python3 tools/preset_vozes.py"""
import glob, os, re
os.chdir(os.path.join(os.path.dirname(__file__), ".."))
falas = sorted(f for f in glob.glob("sounds/*") if re.match(r"sounds/v_.*\.(wav|ogg)$", f))
cfg = open("export_presets.cfg").read()
cfg = re.sub(r'\n\[preset\.1\].*', '', cfg, flags=re.S)       # recria o preset das vozes a cada vez
cfg = cfg.replace('exclude_filter="tools/*"', 'exclude_filter="tools/*,sounds/v_*"')
lista = ", ".join('"res://%s"' % f for f in falas)
cfg = cfg.rstrip("\n") + '''

[preset.1]

name="Vozes"
platform="Web"
runnable=false
dedicated_server=false
custom_features=""
export_filter="resources"
export_files=PackedStringArray(%s)
include_filter=""
exclude_filter=""
export_path="build/web/vozes.pck"
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false

[preset.1.options]

custom_template/debug=""
custom_template/release=""
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=true
html/export_icon=false
html/custom_html_shell=""
html/head_include=""
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
html/experimental_virtual_keyboard=true
progressive_web_app/enabled=false
''' % lista
open("export_presets.cfg", "w").write(cfg)
print(len(falas), "falas no pacote de vozes")

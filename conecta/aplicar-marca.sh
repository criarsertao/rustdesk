#!/bin/bash
# ConectaCliente Remoto — aplica a marca e o servidor no código do RustDesk antes de compilar.
# Roda na nuvem (GitHub Actions), na raiz do repositório.
set -euo pipefail

NOME="Conecta Cliente"
HOST="suporte.minhatela.com.br"
API="https://suporte.minhatela.com.br"
KEY="GkY65x6q+UAi3Vvm4DFwMrdbdGUFDT1UrvTyoBepHL0="
APP_ID="br.com.minhatela.conectacliente"
D="$(cd "$(dirname "$0")" && pwd)"

conferir() { grep -q "$2" "$1" || { echo "ERRO: não apliquei '$2' em $1"; exit 1; }; }

# ---------------------------------------------------------------- 1. Servidor, chave e nome (motor Rust)
CFG=libs/hbb_common/src/config.rs
sed -i "s|&\[\"rs-ny.rustdesk.com\"\]|\&[\"$HOST\"]|" "$CFG"
sed -i "s|pub const RS_PUB_KEY: &str = \"[^\"]*\";|pub const RS_PUB_KEY: \&str = \"$KEY\";|" "$CFG"
sed -i "s|RwLock::new(\"RustDesk\".to_owned())|RwLock::new(\"$NOME\".to_owned())|" "$CFG"
conferir "$CFG" "$HOST"; conferir "$CFG" "$KEY"; conferir "$CFG" "\"$NOME\".to_owned()"

sed -i "s|^\(\s*\)\"https://admin.rustdesk.com\".to_owned()|\1\"$API\".to_owned()|" src/common.rs
conferir src/common.rs "\"$API\".to_owned()"

# ---------------------------------------------------------------- 2. Traduções: troca o nome só no TEXTO exibido
python3 - "$NOME" <<'PY'
import glob, re, sys
nome = sys.argv[1]
par = re.compile(r'^(\s*\("(?:[^"\\]|\\.)*",\s*")((?:[^"\\]|\\.)*)("\),?\s*)$')
total = 0
for f in glob.glob("src/lang/*.rs"):
    linhas = open(f, encoding="utf-8").read().split("\n")
    for i, l in enumerate(linhas):
        m = par.match(l)
        if m and "RustDesk" in m.group(2):
            linhas[i] = m.group(1) + m.group(2).replace("RustDesk", nome) + m.group(3)
            total += 1
    open(f, "w", encoding="utf-8").write("\n".join(linhas))
print("traduções alteradas:", total)
PY

# ---------------------------------------------------------------- 3. Flutter: título com logo + cores da marca
python3 - "$NOME" <<'PY'
import sys
nome = sys.argv[1]
def trocar(arq, de, para, obrigatorio=True):
    t = open(arq, encoding="utf-8").read()
    if de not in t:
        if obrigatorio: raise SystemExit(f"ERRO: trecho não encontrado em {arq}: {de[:60]}")
        return
    open(arq, "w", encoding="utf-8").write(t.replace(de, para))

hp = "flutter/lib/mobile/pages/home_page.dart"
trocar(hp, "    return Text(bind.mainGetAppNameSync());",
"""    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/conecta_icone.png', height: 34),
        const SizedBox(width: 10),
        Text(bind.mainGetAppNameSync(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );""")

cm = "flutter/lib/common.dart"
trocar(cm, "static const Color accent = Color(0xFF0071FF);", "static const Color accent = Color(0xFF0054C8);")
trocar(cm, "static const Color accent50 = Color(0x770071FF);", "static const Color accent50 = Color(0x770054C8);")
trocar(cm, "static const Color accent80 = Color(0xAA0071FF);", "static const Color accent80 = Color(0xAA0054C8);")
trocar(cm, "static const Color button = Color(0xFF2C8CFF);", "static const Color button = Color(0xFF0054C8);")
trocar(cm, "static const Color idColor = Color(0xFF00B6F0);", "static const Color idColor = Color(0xFF0054C8);")
# tema claro: barra do topo azul-marinho
trocar(cm, "primary: Colors.blue, secondary: accent, background: grayBg),",
           "primary: Color(0xFF01195A), secondary: accent, background: grayBg),")
trocar(cm, """    appBarTheme: AppBarTheme(
      shadowColor: Colors.transparent,
    ),""", """    appBarTheme: AppBarTheme(
      shadowColor: Colors.transparent,
      backgroundColor: Color(0xFF01195A),
      foregroundColor: Colors.white,
    ),""")
print("flutter ok")
PY
cp "$D/conecta_icone.png" flutter/assets/conecta_icone.png

# ---------------------------------------------------------------- 4. Android: nome, identificador e ícones
AM=flutter/android/app/src/main/AndroidManifest.xml
sed -i "s|android:label=\"RustDesk Input\"|android:label=\"$NOME\"|; s|android:label=\"RustDesk\"|android:label=\"$NOME\"|" "$AM"
conferir "$AM" "android:label=\"$NOME\""
ST=flutter/android/app/src/main/res/values/strings.xml
sed -i "s|>RustDesk<|>$NOME<|; s|when RustDesk screen|when $NOME screen|; s|Keeps the RustDesk remote|Keeps the $NOME remote|" "$ST"
sed -i "s|<color name=\"ic_launcher_background\">[^<]*</color>|<color name=\"ic_launcher_background\">#0336B0</color>|" flutter/android/app/src/main/res/values/ic_launcher_background.xml
sed -i "s|applicationId \"com.carriez.flutter_hbb\"|applicationId \"$APP_ID\"|" flutter/android/app/build.gradle
conferir flutter/android/app/build.gradle "applicationId \"$APP_ID\""
cp -r "$D/res/." flutter/android/app/src/main/res/

echo "Marca ConectaCliente aplicada."

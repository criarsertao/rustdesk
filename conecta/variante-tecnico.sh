#!/bin/bash
# Variante "Conecta Controle": só para o celular do TÉCNICO controlar outros aparelhos.
# Sem serviço de acessibilidade e sem iniciar com o celular — é isso que faz o
# Play Protect bloquear a instalação. Roda depois do aplicar-marca.sh, na raiz do repositório.
set -euo pipefail
NOME="Conecta Controle"
APP_ID="br.com.minhatela.conectacontrole"

python3 - "$NOME" <<'PY'
import re, sys
nome = sys.argv[1]
am = "flutter/android/app/src/main/AndroidManifest.xml"
t = open(am, encoding="utf-8").read()
antes = t
t = re.sub(r'\s*<service\s+android:name="\.InputService".*?</service>', "", t, flags=re.S)
t = re.sub(r'\s*<receiver\s+android:name="\.BootReceiver".*?</receiver>', "", t, flags=re.S)
t = re.sub(r'\s*<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />', "", t)
t = re.sub(r'android:label="[^"]*"', f'android:label="{nome}"', t)
if "InputService" in t or "BootReceiver" in t or t == antes:
    raise SystemExit("ERRO: manifesto do técnico não foi alterado")
open(am, "w", encoding="utf-8").write(t)
print("manifesto do técnico ok")
PY

ST=flutter/android/app/src/main/res/values/strings.xml
sed -i "s|>Conecta Cliente<|>$NOME<|" "$ST"
sed -i "s|applicationId \"br.com.minhatela.conectacliente\"|applicationId \"$APP_ID\"|" flutter/android/app/build.gradle
grep -q "applicationId \"$APP_ID\"" flutter/android/app/build.gradle || { echo "ERRO: applicationId"; exit 1; }
echo "Variante Conecta Controle aplicada."

#!/usr/bin/env python3
"""
Prueba rápida: ¿funciona el parámetro fields para obtener solo snippet?
Usa el ID del mensaje de gmail_nu_sample.json si existe.
"""
import os
import sys
import json
import urllib.request
import urllib.error
import urllib.parse

# ID del mensaje Nubank (de gmail_nu_sample.json)
MSG_ID = "19c43d6e9d094965"

def main():
    token = os.environ.get("GMAIL_ACCESS_TOKEN")
    if not token:
        print("Define GMAIL_ACCESS_TOKEN y ejecuta de nuevo.")
        sys.exit(1)

    # Request con fields=id,snippet,internalDate
    url = f"https://gmail.googleapis.com/gmail/v1/users/me/messages/{MSG_ID}?fields=id,snippet,internalDate"
    req = urllib.request.Request(url)
    req.add_header("Authorization", f"Bearer {token}")

    print("Request: GET .../messages/{}?fields=id,snippet,internalDate".format(MSG_ID))
    print()

    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode())
        print("ÉXITO - Respuesta:")
        print(json.dumps(data, indent=2, ensure_ascii=False))
        print()
        print("El parámetro fields SÍ funciona. Solo se retornó id, snippet e internalDate.")
    except urllib.error.HTTPError as e:
        print(f"ERROR {e.code}: {e.reason}")
        print(e.read().decode() if e.fp else "")
        sys.exit(1)

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
Script de prueba para obtener un correo de Nubank desde Gmail API.
NO modifica el código de la app - solo hace un request para ver el formato del email.

Uso:
1. Obtén un access token desde: https://developers.google.com/oauthplayground/
   - Paso 1: En "Input your own scopes" escribe EXACTAMENTE:
     https://www.googleapis.com/auth/gmail.readonly
     (NO uses gmail.metadata - ese scope no permite filtrar con 'q')
   - Paso 2: "Authorize APIs" → inicia sesión con tu Gmail
   - Paso 3: "Exchange authorization code for tokens"
   - Paso 4: Copia el "Access token"

2. Ejecuta:
   GMAIL_ACCESS_TOKEN="tu_token_aqui" python3 scripts/fetch_gmail_nu.py

   O pega el token cuando el script lo pida.
"""

import os
import sys
import json
import base64
import tempfile
import urllib.request
import urllib.error
import urllib.parse
from datetime import date

# Configuración del correo a buscar
EMAIL_FROM = "nu@nu.com.co"
SUBJECT_CONTAINS = "Pagaste en GOU PAYMENTS"
# 9 feb 2026 (lunes) - rango para capturar ese día
AFTER_DATE = "2026/02/09"
BEFORE_DATE = "2026/02/10"


def get_access_token() -> str:
    token = os.environ.get("GMAIL_ACCESS_TOKEN")
    if token:
        return token
    print("Pega tu access token de OAuth Playground (o define GMAIL_ACCESS_TOKEN):")
    return input().strip()


def list_messages_with_q(access_token: str) -> list:
    """Lista mensajes con filtro from + fechas (requiere scope gmail.readonly)."""
    q = f"from:{EMAIL_FROM} after:{AFTER_DATE} before:{BEFORE_DATE}"
    url = f"https://gmail.googleapis.com/gmail/v1/users/me/messages?q={urllib.parse.quote(q)}&maxResults=10"
    req = urllib.request.Request(url)
    req.add_header("Authorization", f"Bearer {access_token}")
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read().decode())
    return data.get("messages", [])


def list_messages_no_q(access_token: str, max_results: int = 100) -> list:
    """Lista mensajes SIN parámetro q (compatible con gmail.metadata).
    Luego filtraremos por From y Date en el cliente."""
    url = f"https://gmail.googleapis.com/gmail/v1/users/me/messages?labelIds=INBOX&maxResults={max_results}"
    req = urllib.request.Request(url)
    req.add_header("Authorization", f"Bearer {access_token}")
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read().decode())
    return data.get("messages", [])


def get_message(access_token: str, msg_id: str, format: str = "full", fields=None) -> dict:
    """Obtiene un mensaje. Si fields está definido, solo retorna esos campos (ej. fields=id,snippet,internalDate)."""
    url = f"https://gmail.googleapis.com/gmail/v1/users/me/messages/{msg_id}?format={format}"
    if fields:
        url += f"&fields={urllib.parse.quote(fields)}"
    req = urllib.request.Request(url)
    req.add_header("Authorization", f"Bearer {access_token}")

    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode())


def decode_body(payload: dict) -> str:
    """Decodifica el body del email (puede estar en parts si es multipart)."""
    if "body" in payload and payload["body"].get("data"):
        return base64.urlsafe_b64decode(payload["body"]["data"]).decode("utf-8", errors="replace")
    if "parts" in payload:
        for part in payload["parts"]:
            if part.get("mimeType") == "text/plain" and part.get("body", {}).get("data"):
                return base64.urlsafe_b64decode(part["body"]["data"]).decode("utf-8", errors="replace")
            if part.get("mimeType") == "text/html" and part.get("body", {}).get("data"):
                return base64.urlsafe_b64decode(part["body"]["data"]).decode("utf-8", errors="replace")
    return ""


def get_header(headers: list, name: str) -> str:
    for h in headers:
        if h.get("name", "").lower() == name.lower():
            return h.get("value", "")
    return ""


def parse_rfc2822_date(date_str: str) -> "datetime|None":
    """Parsea fecha RFC 2822 (ej. Mon, 9 Feb 2026 08:06:00 -0500)."""
    from email.utils import parsedate_to_datetime
    try:
        return parsedate_to_datetime(date_str)
    except Exception:
        return None


def is_from_nu_and_in_range(from_header: str, date_header: str) -> bool:
    """Verifica si el correo es de nu@nu.com.co y está en el rango de fechas."""
    if EMAIL_FROM.lower() not in from_header.lower():
        return False
    dt = parse_rfc2822_date(date_header)
    if not dt:
        return True  # Si no podemos parsear, incluirlo
    # Parsear AFTER_DATE y BEFORE_DATE (formato YYYY/MM/DD)
    parts_after = [int(x) for x in AFTER_DATE.split("/")]
    parts_before = [int(x) for x in BEFORE_DATE.split("/")]
    msg_date = dt.date()
    after_date = date(parts_after[0], parts_after[1], parts_after[2])
    before_date = date(parts_before[0], parts_before[1], parts_before[2])
    return after_date <= msg_date < before_date


def main():
    token = get_access_token()
    if not token:
        print("Error: Se necesita un access token.")
        sys.exit(1)

    print(f"\nBuscando correos de {EMAIL_FROM} entre {AFTER_DATE} y {BEFORE_DATE}...\n")

    messages = []

    try:
        messages = list_messages_with_q(token)
    except urllib.error.HTTPError as e:
        body = e.read().decode() if e.fp else ""
        if "Metadata scope does not support 'q' parameter" in body:
            print("(Tu token usa gmail.metadata - listando sin filtro y filtrando localmente...)\n")
            try:
                all_msgs = list_messages_no_q(token)
                for m in all_msgs:
                    msg_full = get_message(token, m["id"])
                    payload = msg_full.get("payload", {})
                    headers = payload.get("headers", [])
                    from_h = get_header(headers, "From")
                    date_h = get_header(headers, "Date")
                    if is_from_nu_and_in_range(from_h, date_h):
                        messages.append({"id": m["id"], "threadId": m.get("threadId")})
                print(f"Encontrados {len(messages)} de {len(all_msgs)} que coinciden.\n")
            except urllib.error.HTTPError as e2:
                print(f"Error: {e2.code} {e2.reason}")
                sys.exit(1)
        else:
            print(f"Error listando mensajes: {e.code} {e.reason}")
            print(body)
            sys.exit(1)

    if not messages:
        print("No se encontraron mensajes. Prueba ampliar el rango de fechas.")
        sys.exit(0)

    msg_id = messages[0]["id"]

    # PRUEBA 1: Request con fields=id,snippet,internalDate (solo lo necesario)
    print("=" * 60)
    print("PRUEBA: Request con fields=id,snippet,internalDate")
    print("=" * 60)
    try:
        msg_minimal = get_message(token, msg_id, fields="id,snippet,internalDate")
        print("Respuesta recibida:")
        print(json.dumps(msg_minimal, indent=2, ensure_ascii=False))
        print(f"\nTamaño respuesta: {len(json.dumps(msg_minimal))} caracteres")
        # Guardar en temp para inspección (no subir a Git; ver gmail_nu_sample_sanitized.json para ejemplo)
        tmp_minimal = os.path.join(tempfile.gettempdir(), "gmail_nu_snippet_only.json")
        with open(tmp_minimal, "w", encoding="utf-8") as f:
            json.dump(msg_minimal, f, indent=2, ensure_ascii=False)
        print(f"Guardado en: {tmp_minimal}")
    except urllib.error.HTTPError as e:
        print(f"ERROR: {e.code} {e.reason}")
        print(e.read().decode() if e.fp else "")
        sys.exit(1)

    # PRUEBA 2: Request completo (para comparar)
    print("\n" + "=" * 60)
    print("Request completo (sin fields) para comparar...")
    print("=" * 60)
    msg = get_message(token, msg_id)
    full_size = len(json.dumps(msg))
    print(f"Tamaño respuesta completa: {full_size} caracteres")
    min_size = len(json.dumps(msg_minimal))
    print(f"Reducción: {full_size} -> {min_size} (~{100 * (1 - min_size/full_size):.0f}% menos)")
    print()

    payload = msg.get("payload", {})
    headers = payload.get("headers", [])

    subject = get_header(headers, "Subject")
    from_h = get_header(headers, "From")
    date_h = get_header(headers, "Date")

    print("=" * 60)
    print("METADATA")
    print("=" * 60)
    print(f"From: {from_h}")
    print(f"Subject: {subject}")
    print(f"Date: {date_h}")
    print()

    body = decode_body(payload)
    print("=" * 60)
    print("BODY (texto plano o HTML)")
    print("=" * 60)
    if not body:
        print("(Vacío - tu token tiene scope gmail.metadata. Usa gmail.readonly para ver el contenido.)")
    else:
        print(body[:3000] if len(body) > 3000 else body)
        if len(body) > 3000:
            print("\n... [truncado, total", len(body), "caracteres]")
    print()

    # Guardar respuesta completa en archivos temporales
    tmp_dir = tempfile.gettempdir()
    json_path = os.path.join(tmp_dir, "gmail_nu_response.json")
    txt_path = os.path.join(tmp_dir, "gmail_nu_response.txt")

    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(msg, f, indent=2, ensure_ascii=False)
    print(f"JSON completo (respuesta cruda de la API): {json_path}")

    with open(txt_path, "w", encoding="utf-8") as f:
        f.write("=== METADATA ===\n")
        f.write(f"From: {from_h}\n")
        f.write(f"Subject: {subject}\n")
        f.write(f"Date: {date_h}\n\n")
        f.write("=== BODY ===\n")
        f.write(body if body else "(vacío - scope gmail.metadata no incluye body)\n")
    print(f"Texto legible (metadata + body): {txt_path}")


if __name__ == "__main__":
    main()

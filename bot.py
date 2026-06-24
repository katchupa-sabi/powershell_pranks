import asyncio
import nest_asyncio
import subprocess
from telegram import Update
from telegram.ext import ApplicationBuilder, CommandHandler, MessageHandler, ContextTypes, filters
import logging
from pathlib import Path

nest_asyncio.apply()
pasta = Path(r"C:\Windows\System32\ap32\Res-PE")

TOKEN_FILE = pasta / "token.txt"
#TOKEN = TOKEN_FILE.read_text(encoding="utf-8").strip()
TOKEN = "8207541788:AAHP3o4r3UKC0Pw6hrgOLUcKpb9n-y780xA"
ADMIN_ID = 123456789


def listar_scripts():
    PS_SCRIPTS = {}
    for item in pasta.iterdir():
        if item.is_file():
            chave = item.stem.lower()
            PS_SCRIPTS[chave] = str(item)
    return PS_SCRIPTS


logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)

# -------------------------
# PERMISSÃO DO ADMIN
# -------------------------
async def verificar_permissao(update: Update):
    if 123456789 != ADMIN_ID:
        await update.message.reply_text("Acesso não autorizado.")
        return False
    return True

# -------------------------
# EXECUTOR DE SCRIPTS
# -------------------------
def executar_script(nome, PS_SCRIPTS):
    caminho = PS_SCRIPTS.get(nome.lower())
    if not caminho:
        return "❌ Script não encontrado."

    try:
        resultado = subprocess.run(
            ["powershell.exe", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", caminho],
            capture_output=True,
            text=True,
            timeout=600
        )

        saida = resultado.stdout.strip()
        erro = resultado.stderr.strip()

        if erro:
            return f"⚠ Erro do PowerShell:\n{erro}"
        if not saida:
            return "✔ Script executado (sem saída)."
        return saida

    except Exception as e:
        return f"❌ Erro ao executar script: {e}"

# -------------------------
# COMANDO /start
# -------------------------
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await verificar_permissao(update): return

    PS_SCRIPTS = listar_scripts()  # lista atualizada
    if not PS_SCRIPTS:
        await update.message.reply_text("Não há scripts disponíveis no momento.")
        return

    lista = "\n".join(f"/{cmd}" for cmd in PS_SCRIPTS.keys())
    await update.message.reply_text(
        "Bot ativo! Scripts permitidos:\n\n" +
        lista +
        "\n\nUse qualquer comando desta lista para executar o script respetivo."
    )

# -------------------------
# HANDLER GENÉRICO PARA QUALQUER COMANDO
# -------------------------
async def comando_generico(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await verificar_permissao(update): return

    PS_SCRIPTS = listar_scripts()  # sempre atualiza
    nome_cmd = update.message.text.replace("/", "").lower()

    if nome_cmd not in PS_SCRIPTS:
        await update.message.reply_text("❌ Script não encontrado.")
        return

    await update.message.reply_text(f"⏳ A executar '{nome_cmd}'...")

    saida = executar_script(nome_cmd, PS_SCRIPTS)

    if len(saida) > 3000:
        with open("saida.txt", "w", encoding="utf-8") as f:
            f.write(saida)
        await update.message.reply_document(open("saida.txt", "rb"))
    else:
        await update.message.reply_text(saida)

# -------------------------
# TEXTO NORMAL
# -------------------------
async def texto(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await verificar_permissao(update): return
    await update.message.reply_text("Comando desconhecido. Use /start para ver os comandos permitidos.")

# -------------------------
# MAIN
# -------------------------
async def main():
    app = ApplicationBuilder().token(TOKEN).build()

    # Comando /start (sempre primeiro!)
    app.add_handler(CommandHandler("start", start))

    # Handler genérico para qualquer outro comando de script
    app.add_handler(MessageHandler(filters.COMMAND & ~filters.Regex(r'^/start'), comando_generico))

    # Mensagens de texto normal
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, texto))

    print("Bot do Telegram em execução...")
    await app.run_polling(close_loop=False)


if __name__ == "__main__":
    asyncio.run(main())




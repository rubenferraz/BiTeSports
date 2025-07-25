import time
import asyncio
import json
import numpy as np
import websockets
from bitalino import BITalino
from db import guardar_ecg, obter_mac_jogador

# =============== CONFIGURAÇÕES ===============
batteryThreshold = 30
acqChannels = [0]
samplingRate = 1000  # Hz
nSamples = 10        # Nº de amostras lidas por bloco

# =============== SERVIDOR WEBSOCKET ===============
async def stream_ecg(websocket, path=None):
    print("🟢 Cliente conectado.")

    try:
        # 🔑 Primeiro recebe o jogador_id e sessao_id
        mensagem_inicial = await websocket.recv()
        dados_iniciais = json.loads(mensagem_inicial)
        print(f"Recebido: {dados_iniciais}")
        jogador_id = dados_iniciais.get("jogador_id")
        sessao_id = dados_iniciais.get("sessao_id")

        if not jogador_id or not sessao_id:
            await websocket.send(json.dumps({"erro": "jogador_id ou sessao_id em falta"}))
            await websocket.close()
            return

        # 🔍 Obtem o MAC do jogador a partir da BD
        macAddress = obter_mac_jogador(jogador_id)
        if not macAddress:
            await websocket.send(json.dumps({"erro": "MAC address não encontrado"}))
            await websocket.close()
            return

        print(f"✅ Ligação associada ao jogador_id {jogador_id} com MAC {macAddress} (sessão {sessao_id})")

        # =============== CONECTAR AO BITALINO ===============
        device = BITalino(macAddress)
        device.battery(batteryThreshold)
        print("Conectado ao BITalino. Versão:", device.version())
        device.start(samplingRate, acqChannels)

        # 🔁 Loop contínuo de leitura e envio
        while True:
            block = device.read(nSamples)
            raw_ecg = block[:, 5]

            ecg_mV = (raw_ecg - 512.0) * (3.3 / 1024.0) / 1100.0 * 1000.0
            ecg_mV = -ecg_mV  # Inversão do sinal

            # Envia para o Flutter
            await websocket.send(json.dumps({
                "timestamp": time.time(),
                "ecg": ecg_mV.tolist()
            }))

            # Guarda no PostgreSQL (com sessao_id)
            for valor in ecg_mV:
                guardar_ecg(jogador_id=jogador_id, valor_mv=float(valor), sessao_id=sessao_id)

            await asyncio.sleep(nSamples / samplingRate)

    except websockets.exceptions.ConnectionClosed:
        print("🔴 Cliente desconectado.")
    except Exception as e:
        print(f"❌ Erro: {e}")

# 🟢 Início do servidor
async def main():
    async with websockets.serve(stream_ecg, "0.0.0.0", 8765):
        print("🚀 Servidor WebSocket em ws://0.0.0.0:8765")
        await asyncio.Future()

if __name__ == "__main__":
    asyncio.run(main())

# BITeSports - ECG em Tempo Real – Sistema BITalino

Sistema para monitorização de ECG em tempo real com **Flutter** (frontend), **Flask** (backend) e **PostgreSQL** (base de dados).

---

## ▶️ Como correr o programa

### 📦 Frontend (Flutter Web)

# Instalar dependências do Flutter
flutter pub get

# Iniciar a app no navegador
flutter run -d chrome

🧠 Backend (Python + Flask)
# Criar ambiente virtual (apenas na 1ª vez)
python -m venv venv

# Ativar ambiente virtual
.\venv\Scripts\activate

# Instalar dependências
pip install -r requirements.txt

# Iniciar aquisição de dados do BITalino
python bitalino_server.py

➡️ Noutro terminal (com venv também ativado):
python app.py

🗃️ Base de Dados (PostgreSQL)
# Aceder à base de dados
psql -U postgres -d ecgdb

```bash

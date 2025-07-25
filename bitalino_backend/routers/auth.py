from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from passlib.context import CryptContext
from jose import jwt
import models, database, config

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
auth_router = APIRouter()

def get_db():
    db = database.SessionLocal()
    try:
        yield db
    finally:
        db.close()

@auth_router.post("/register")
def register(username: str, password: str, db: Session = Depends(get_db)):
    hashed_password = pwd_context.hash(password)
    new_treinador = models.Treinador(username=username, password=hashed_password)
    db.add(new_treinador)
    db.commit()
    return {"message": "Treinador registado"}

@auth_router.post("/login")
def login(username: str, password: str, db: Session = Depends(get_db)):
    treinador = db.query(models.Treinador).filter(models.Treinador.username == username).first()
    if not treinador or not pwd_context.verify(password, treinador.password):
        raise HTTPException(status_code=401, detail="Credenciais inválidas")

    token = jwt.encode({"sub": treinador.username}, config.SECRET_KEY, algorithm=config.ALGORITHM)
    return {"access_token": token}

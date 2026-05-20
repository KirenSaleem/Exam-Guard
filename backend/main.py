from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles

from routes.auth import router as auth_router
from routes.classroom import router as classroom_router
from routes.exam_session import router as exam_router
from routes.exam_history import router as exam_history_router
# from routes.monitoring import router as monitoring_router
from routes.student import router as student_router
from routes.teacher import router as teacher_router

app = FastAPI(title="ExamGuard Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(teacher_router)
app.include_router(student_router)
app.include_router(classroom_router)
app.include_router(exam_router)
app.include_router(exam_history_router)
# app.include_router(monitoring_router)
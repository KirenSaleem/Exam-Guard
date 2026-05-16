from fastapi import APIRouter, File, Form, HTTPException, UploadFile

from services.student_service import get_students_by_classroom, register_student

router = APIRouter(prefix="/students", tags=["students"])


@router.post("/register")
async def register_student_route(
    classroom_code: str = Form(...),
    name: str = Form(...),
    roll_number: str = Form(...),
    profile_image: UploadFile = File(...),
):
    if not classroom_code.strip():
        raise HTTPException(status_code=400, detail="classroom_code is required.")
    if not name.strip():
        raise HTTPException(status_code=400, detail="name is required.")
    if not roll_number.strip():
        raise HTTPException(status_code=400, detail="roll_number is required.")
    if not profile_image.filename:
        raise HTTPException(status_code=400, detail="profile_image is required.")

    try:
        student = register_student(classroom_code, name, roll_number, profile_image)
        return {"message": "Registration successful", "student": student}
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.get("/classroom/{classroom_id}")
def get_classroom_students_route(classroom_id: str):
    students = get_students_by_classroom(classroom_id)
    return {"students": students}

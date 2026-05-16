import shutil
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional
from uuid import uuid4

from db.database import classrooms_collection, students_collection
from models.student import StudentRecord

STUDENTS_DIR = Path(__file__).resolve().parent.parent / "storage" / "students"
STUDENTS_DIR.mkdir(parents=True, exist_ok=True)


def _serialize_student(student_doc: Dict[str, Any]) -> Dict[str, Any]:
    student_doc.pop("_id", None)
    submitted_at = student_doc.get("submitted_at")
    if isinstance(submitted_at, datetime):
        student_doc["submitted_at"] = submitted_at.isoformat()
    return student_doc


def _save_profile_image(upload_file) -> str:
    extension = Path(upload_file.filename or "photo.jpg").suffix or ".jpg"
    filename = f"{uuid4()}{extension}"
    destination = STUDENTS_DIR / filename
    with destination.open("wb") as buffer:
        shutil.copyfileobj(upload_file.file, buffer)
    return f"/students/{filename}"


def register_student(
    classroom_code: str,
    name: str,
    roll_number: str,
    upload_file,
) -> Dict[str, Any]:
    normalized_code = classroom_code.strip().upper()
    classroom = classrooms_collection.find_one({"classroom_code": normalized_code})
    if not classroom:
        raise ValueError("Invalid classroom code.")

    classroom_id = classroom["classroom_id"]
    existing = students_collection.find_one(
        {"classroom_id": classroom_id, "roll_number": roll_number.strip()}
    )
    if existing:
        raise ValueError("A student with this roll number is already registered.")

    profile_path = _save_profile_image(upload_file)
    student = StudentRecord(
        student_id=str(uuid4()),
        classroom_id=classroom_id,
        classroom_code=normalized_code,
        name=name.strip(),
        roll_number=roll_number.strip(),
        profile_image=profile_path,
    )
    student_dict = student.model_dump()
    student_dict["submitted_at"] = datetime.utcnow()
    students_collection.insert_one(student_dict)

    classrooms_collection.update_one(
        {"classroom_id": classroom_id},
        {"$addToSet": {"students": student.student_id}},
    )
    return _serialize_student(student_dict)


def get_students_by_classroom(classroom_id: str) -> List[Dict[str, Any]]:
    cursor = students_collection.find({"classroom_id": classroom_id}).sort("submitted_at", -1)
    return [_serialize_student(doc) for doc in cursor]


def get_student_ids_for_classroom(classroom_id: str) -> List[str]:
    students = students_collection.find(
        {"classroom_id": classroom_id},
        {"student_id": 1, "_id": 0},
    )
    return [doc["student_id"] for doc in students]

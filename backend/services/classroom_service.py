import secrets
import string
from datetime import datetime
from typing import Any, Dict, List, Optional
from uuid import uuid4

from db.database import classrooms_collection, students_collection, teachers_collection
from models.classroom import Classroom


def _serialize_classroom(classroom_doc: Dict[str, Any]) -> Dict[str, Any]:
    classroom_doc.pop("_id", None)
    created_at = classroom_doc.get("created_at")
    if isinstance(created_at, datetime):
        classroom_doc["created_at"] = created_at.isoformat()
    classroom_doc = _attach_member_details(classroom_doc)
    return classroom_doc


def _generate_unique_code(length: int = 6) -> str:
    alphabet = string.ascii_uppercase + string.digits
    while True:
        code = "".join(secrets.choice(alphabet) for _ in range(length))
        existing = classrooms_collection.find_one({"classroom_code": code})
        if not existing:
            return code


def _serialize_student_summary(student_doc: Dict[str, Any]) -> Dict[str, Any]:
    student_doc.pop("_id", None)
    submitted_at = student_doc.get("submitted_at")
    if isinstance(submitted_at, datetime):
        student_doc["submitted_at"] = submitted_at.isoformat()
    return student_doc


def _attach_member_details(classroom_doc: Dict[str, Any]) -> Dict[str, Any]:
    classroom_id = classroom_doc.get("classroom_id", "")
    teachers: List[str] = classroom_doc.get("teachers", [])

    teachers_cursor = teachers_collection.find(
        {"firebase_uid": {"$in": teachers}},
        {"_id": 0, "firebase_uid": 1, "name": 1, "profile_image": 1},
    )
    user_map = {doc.get("firebase_uid"): doc for doc in teachers_cursor}
    classroom_doc["teachers_details"] = [
        user_map[uid] for uid in teachers if uid in user_map
    ]

    # Live count from students collection (not cached classroom.students array).
    classroom_doc["student_count"] = students_collection.count_documents(
        {"classroom_id": classroom_id}
    )

    students_cursor = students_collection.find(
        {"classroom_id": classroom_id},
        {
            "_id": 0,
            "student_id": 1,
            "name": 1,
            "roll_number": 1,
            "profile_image": 1,
            "submitted_at": 1,
        },
    ).sort("submitted_at", -1)
    classroom_doc["students_details"] = [
        _serialize_student_summary(doc) for doc in students_cursor
    ]
    return classroom_doc


def get_classroom_by_id(classroom_id: str) -> Optional[Dict[str, Any]]:
    classroom_doc = classrooms_collection.find_one({"classroom_id": classroom_id})
    if not classroom_doc:
        return None
    return _serialize_classroom(classroom_doc)


def create_classroom(classroom_name: str, created_by: str) -> Dict[str, Any]:
    classroom = Classroom(
        classroom_id=str(uuid4()),
        classroom_name=classroom_name,
        created_by=created_by,
        classroom_code=_generate_unique_code(),
        teachers=[created_by],
        students=[],
    )
    classroom_dict = classroom.model_dump()
    classrooms_collection.insert_one(classroom_dict)
    return _serialize_classroom(classroom_dict)


def join_classroom(firebase_uid: str, classroom_code: str) -> Dict[str, Any]:
    teacher_doc = teachers_collection.find_one({"firebase_uid": firebase_uid})
    if not teacher_doc:
        raise ValueError("Teacher profile not found. Please complete profile setup first.")

    normalized_code = classroom_code.upper()
    classroom_doc = classrooms_collection.find_one({"classroom_code": normalized_code})
    if not classroom_doc:
        raise ValueError("Invalid classroom code.")

    teachers: List[str] = classroom_doc.get("teachers", [])
    if firebase_uid in teachers:
        return _serialize_classroom(classroom_doc)

    classrooms_collection.update_one(
        {"classroom_code": normalized_code},
        {"$addToSet": {"teachers": firebase_uid}},
    )
    updated_doc = classrooms_collection.find_one({"classroom_code": normalized_code})
    return _serialize_classroom(updated_doc) if updated_doc else _serialize_classroom(classroom_doc)


def get_teacher_classrooms(firebase_uid: str) -> List[Dict[str, Any]]:
    classrooms = classrooms_collection.find({"teachers": firebase_uid})
    return [_serialize_classroom(doc) for doc in classrooms]

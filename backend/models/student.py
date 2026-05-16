from datetime import datetime

from pydantic import BaseModel, Field


class StudentRegistrationRequest(BaseModel):
    classroom_code: str
    name: str
    roll_number: str


class StudentRecord(BaseModel):
    student_id: str
    classroom_id: str
    classroom_code: str
    name: str
    roll_number: str
    profile_image: str
    submitted_at: datetime = Field(default_factory=datetime.utcnow)

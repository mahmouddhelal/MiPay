from pydantic import BaseModel, ConfigDict


class CategoryOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    key: str
    label_en: str
    label_ar: str
    icon: str
    kind: str
    sort_order: int

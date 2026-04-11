from pydantic import BaseModel


class EmailAddressSchema(BaseModel):
    id: str
    email_address: str


class ClerkWebhookUser(BaseModel):
    id: str
    email_addresses: list[EmailAddressSchema]
    first_name: str | None = None
    last_name: str | None = None
    image_url: str | None = None


class UserRead(BaseModel):
    id: str
    email: str
    display_name: str | None
    avatar_url: str | None

    model_config = {"from_attributes": True}

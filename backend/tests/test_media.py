from app.api.media import _matches_file_signature


def test_media_signature_validation_accepts_supported_headers() -> None:
    assert _matches_file_signature(".jpg", b"\xff\xd8\xffimage")
    assert _matches_file_signature(".png", b"\x89PNG\r\n\x1a\nimage")
    assert _matches_file_signature(".webp", b"RIFF1234WEBPdata")
    assert _matches_file_signature(".mp4", b"\x00\x00\x00\x18ftypmp42")


def test_media_signature_validation_rejects_disguised_content() -> None:
    assert not _matches_file_signature(".jpg", b"<script>alert(1)</script>")
    assert not _matches_file_signature(".mp4", b"not-a-video")

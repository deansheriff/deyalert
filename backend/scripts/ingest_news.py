"""Fetch configured publisher feeds and create reviewable security advisories."""

from app.services.news_ingestion import NewsIngestionPipeline


def main() -> None:
    processed, created = NewsIngestionPipeline().run()
    print(
        f"Security news ingestion complete: {processed} relevant, "
        f"{created} new",
        flush=True,
    )


if __name__ == "__main__":
    main()

from pathlib import Path


def relative_to_posix(path: Path) -> str:
    return path.as_posix()


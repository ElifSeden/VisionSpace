from pathlib import Path

from enrich_products import enrich_file, load_env, resolve_input_path


def prompt_positive_int(message: str) -> int:
    while True:
        raw = input(message).strip()
        try:
            value = int(raw)
        except ValueError:
            print("Enter a whole number greater than 0.")
            continue
        if value > 0:
            return value
        print("Value must be greater than 0.")


def prompt_limit() -> int | None:
    while True:
        raw = input("How many to preprocess in JSON file? (all, or amount): ").strip().lower()
        if raw in {"all", "a", "*", ""}:
            return None
        try:
            value = int(raw)
        except ValueError:
            print("Enter 'all' or a whole number greater than 0.")
            continue
        if value > 0:
            return value
        print("Amount must be greater than 0.")


def main() -> None:
    load_env()
    parallel_requests = prompt_positive_int("How many parallel requests? ")
    limit = prompt_limit()

    input_path = resolve_input_path("products.jsonl")
    if not input_path.exists():
        raise FileNotFoundError("Input file not found: products.jsonl")

    print("\nStarting preprocessor with:")
    print(f"  input: {input_path}")
    print("  output: enriched_products.jsonl")
    print("  errors: enrichment_errors.jsonl")
    print(f"  parallel requests: {parallel_requests}")
    print(f"  amount: {'all' if limit is None else limit}")

    enrich_file(
        input_path=input_path,
        output_path=Path("enriched_products.jsonl"),
        error_path=Path("enrichment_errors.jsonl"),
        limit=limit,
        parallel_requests=parallel_requests,
    )
    print("Preprocessor finished.")


if __name__ == "__main__":
    main()

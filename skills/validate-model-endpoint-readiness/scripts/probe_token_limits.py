#!/usr/bin/env python3
"""Probe OpenAI-compatible context and output token limits without saving content."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


DEFAULT_MINIMUM_OUTPUT_TOKENS = 16_384


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-url", default=os.getenv("OPENAI_BASE_URL"))
    parser.add_argument("--model", default=os.getenv("OPENAI_MODEL"))
    parser.add_argument("--api-key-env", default="OPENAI_API_KEY")
    parser.add_argument("--context-window", type=int, required=True)
    parser.add_argument("--context-prompt-file", type=Path, required=True)
    parser.add_argument(
        "--expected-context-input-tokens", type=int, required=True,
        help="Token count for the fully templated request from the official tokenizer.",
    )
    parser.add_argument("--context-response-tokens", type=int, default=32)
    parser.add_argument("--context-tolerance-tokens", type=int, default=64)
    parser.add_argument(
        "--minimum-output-tokens", type=int,
        default=DEFAULT_MINIMUM_OUTPUT_TOKENS,
    )
    parser.add_argument("--timeout-seconds", type=float, default=1800.0)
    parser.add_argument("--evidence-json", type=Path)
    parser.add_argument("--allow-live-traffic", action="store_true")
    return parser.parse_args()


def token_count(usage: dict[str, Any], *names: str) -> int | None:
    for name in names:
        value = usage.get(name)
        if isinstance(value, int):
            return value
    return None


def request_json(
    *, base_url: str, api_key: str | None, payload: dict[str, Any], timeout: float
) -> tuple[dict[str, Any], float]:
    url = f"{base_url.rstrip('/')}/chat/completions"
    headers = {"Content-Type": "application/json"}
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"
    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers=headers,
        method="POST",
    )
    started = time.monotonic()
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            body = response.read()
    except urllib.error.HTTPError as error:
        detail = error.read(4096).decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {error.code}: {detail}") from error
    except urllib.error.URLError as error:
        raise RuntimeError(f"request failed: {error.reason}") from error
    elapsed = time.monotonic() - started
    try:
        decoded = json.loads(body)
    except json.JSONDecodeError as error:
        raise RuntimeError("endpoint returned non-JSON content") from error
    if not isinstance(decoded, dict):
        raise RuntimeError("endpoint returned a non-object JSON response")
    return decoded, elapsed


def response_metadata(response: dict[str, Any], elapsed: float) -> dict[str, Any]:
    choices = response.get("choices") or []
    choice = choices[0] if choices and isinstance(choices[0], dict) else {}
    message = choice.get("message") if isinstance(choice.get("message"), dict) else {}
    content = message.get("content") if isinstance(message, dict) else None
    content_bytes = content.encode("utf-8") if isinstance(content, str) else b""
    return {
        "response_id": response.get("id"),
        "finish_reason": choice.get("finish_reason"),
        "elapsed_seconds": round(elapsed, 3),
        "content_bytes": len(content_bytes),
        "content_sha256": hashlib.sha256(content_bytes).hexdigest(),
    }


def run_context_probe(args: argparse.Namespace, api_key: str | None) -> dict[str, Any]:
    prompt = args.context_prompt_file.read_text(encoding="utf-8")
    required_input = (
        args.context_window
        - args.context_response_tokens
        - args.context_tolerance_tokens
    )
    result: dict[str, Any] = {
        "gate": "full_context_window",
        "advertised_context_tokens": args.context_window,
        "requested_output_tokens": args.context_response_tokens,
        "tolerance_tokens": args.context_tolerance_tokens,
        "expected_input_tokens": args.expected_context_input_tokens,
        "required_minimum_input_tokens": required_input,
        "prompt_bytes": len(prompt.encode("utf-8")),
        "prompt_sha256": hashlib.sha256(prompt.encode("utf-8")).hexdigest(),
    }
    if args.expected_context_input_tokens < required_input:
        result.update(
            status="FAILED",
            error="prepared prompt is not close enough to the advertised boundary",
        )
        return result
    payload = {
        "model": args.model,
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": args.context_response_tokens,
        "temperature": 0,
    }
    try:
        response, elapsed = request_json(
            base_url=args.base_url, api_key=api_key, payload=payload,
            timeout=args.timeout_seconds,
        )
    except RuntimeError as error:
        result.update(status="FAILED", error=str(error))
        return result
    usage = response.get("usage") if isinstance(response.get("usage"), dict) else {}
    observed_input = token_count(usage, "prompt_tokens", "input_tokens")
    result.update(response_metadata(response, elapsed))
    result["observed_input_tokens"] = observed_input
    if observed_input is None:
        result.update(status="BLOCKED", error="response did not report input-token usage")
    elif observed_input < required_input:
        result.update(status="FAILED", error="live input usage was below the boundary requirement")
    else:
        result["status"] = "PASSED"
    return result


def run_output_probe(args: argparse.Namespace, api_key: str | None) -> dict[str, Any]:
    result: dict[str, Any] = {
        "gate": "default_minimum_output_tokens",
        "required_output_tokens": args.minimum_output_tokens,
        "client_output_limit_omitted": True,
    }
    payload = {
        "model": args.model,
        "messages": [{
            "role": "user",
            "content": (
                "Generate at least 20000 tokens as a continuous numbered list of "
                "short factual statements. Do not conclude, summarize, or stop "
                "voluntarily before reaching 20000 tokens."
            ),
        }],
        "temperature": 0,
    }
    try:
        response, elapsed = request_json(
            base_url=args.base_url, api_key=api_key, payload=payload,
            timeout=args.timeout_seconds,
        )
    except RuntimeError as error:
        result.update(status="FAILED", error=str(error))
        return result
    usage = response.get("usage") if isinstance(response.get("usage"), dict) else {}
    observed_output = token_count(usage, "completion_tokens", "output_tokens")
    result.update(response_metadata(response, elapsed))
    result["observed_output_tokens"] = observed_output
    if observed_output is None:
        result.update(status="BLOCKED", error="response did not report output-token usage")
    elif observed_output < args.minimum_output_tokens:
        if result.get("finish_reason") == "length":
            result.update(
                status="FAILED",
                error="endpoint clipped default output below the 16K requirement",
            )
        else:
            result.update(
                status="BLOCKED",
                error="model stopped voluntarily before the default output floor was proven",
            )
    else:
        result["status"] = "PASSED"
    return result


def main() -> int:
    args = parse_args()
    if not args.allow_live_traffic:
        print(
            "refusing live probes without --allow-live-traffic; review endpoint, "
            "credential, and token cost first",
            file=sys.stderr,
        )
        return 2
    if not args.base_url or not args.model:
        print("--base-url and --model are required", file=sys.stderr)
        return 2
    for name, value in (
        ("context-window", args.context_window),
        ("expected-context-input-tokens", args.expected_context_input_tokens),
        ("context-response-tokens", args.context_response_tokens),
        ("minimum-output-tokens", args.minimum_output_tokens),
    ):
        if value <= 0:
            print(f"--{name} must be positive", file=sys.stderr)
            return 2
    if args.context_response_tokens + args.context_tolerance_tokens >= args.context_window:
        print("context response plus tolerance must be below the context window", file=sys.stderr)
        return 2
    if not args.context_prompt_file.is_file():
        print(f"context prompt not found: {args.context_prompt_file}", file=sys.stderr)
        return 2

    api_key = os.getenv(args.api_key_env)
    evidence = {
        "schema_version": 1,
        "endpoint": args.base_url,
        "model": args.model,
        "credential_env": args.api_key_env if api_key else None,
        "content_retained": False,
        "probes": [
            run_context_probe(args, api_key),
            run_output_probe(args, api_key),
        ],
    }
    statuses = {probe["status"] for probe in evidence["probes"]}
    evidence["status"] = (
        "FAILED" if "FAILED" in statuses
        else "BLOCKED" if "BLOCKED" in statuses
        else "PASSED"
    )
    rendered = json.dumps(evidence, indent=2, sort_keys=True)
    print(rendered)
    if args.evidence_json:
        args.evidence_json.parent.mkdir(parents=True, exist_ok=True)
        args.evidence_json.write_text(rendered + "\n", encoding="utf-8")
    return 0 if evidence["status"] == "PASSED" else 1


if __name__ == "__main__":
    raise SystemExit(main())

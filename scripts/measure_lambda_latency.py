#!/usr/bin/env python3
"""
Measure cold start and warm request latency for the torpin Swift Lambda endpoint.

Examples:
  python3 scripts/measure_lambda_latency.py --cold-start-waits 900 --warm-requests 5
  python3 scripts/measure_lambda_latency.py --url https://api.isbriantorp.in/v1/ --idle-between 2 --warm-requests 10
"""

import argparse
import concurrent.futures
import json
import os
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from statistics import mean
from typing import Dict, List, Optional


def parse_args() -> argparse.Namespace:
  parser = argparse.ArgumentParser(
    description="Probe the torpin API to measure cold start and warm latency."
  )
  parser.add_argument(
    "--url",
    default=os.environ.get("TORPIN_API_URL", "https://api.isbriantorp.in/v1/"),
    help="Endpoint to probe (default: https://api.isbriantorp.in/v1/ or TORPIN_API_URL env var)",
  )
  parser.add_argument(
    "--cold-start-waits",
    type=float,
    nargs="*",
    default=[],
    help=(
      "Seconds to wait before each cold-start probe. "
      "Use large waits (e.g. 900) to let the Lambda container freeze."
    ),
  )
  parser.add_argument(
    "--warm-requests",
    type=int,
    default=10,
    help="Number of back-to-back warm requests to send after cold-start probes.",
  )
  parser.add_argument(
    "--idle-between",
    type=float,
    default=0.0,
    help="Seconds to wait between warm requests to simulate load patterns.",
  )
  parser.add_argument(
    "--timeout",
    type=float,
    default=10.0,
    help="HTTP timeout in seconds per request.",
  )
  parser.add_argument(
    "--output-json",
    help="Optional path to write detailed results as JSON.",
  )
  parser.add_argument(
    "--burst-requests",
    type=int,
    default=0,
    help="Number of concurrent burst requests to send after warm sequential probes.",
  )
  parser.add_argument(
    "--burst-concurrency",
    type=int,
    default=5,
    help="Max concurrent workers to use for burst requests.",
  )
  return parser.parse_args()


def percentile(values: List[float], percentile_rank: float) -> float:
  if not values:
    return 0.0
  position = (len(values) - 1) * percentile_rank
  lower = int(position)
  upper = min(lower + 1, len(values) - 1)
  weight = position - lower
  return values[lower] * (1 - weight) + values[upper] * weight


def probe(url: str, timeout: float, phase: str, sequence: int) -> Dict[str, object]:
  started_at = datetime.now(timezone.utc)
  start = time.perf_counter()
  status: Optional[int] = None
  error: Optional[str] = None

  try:
    with urllib.request.urlopen(url, timeout=timeout) as response:
      status = response.getcode()
      response.read()
  except urllib.error.HTTPError as exc:
    status = exc.code
    error = str(exc)
  except Exception as exc:  # pragma: no cover - defensive fallback
    error = str(exc)

  elapsed_ms = (time.perf_counter() - start) * 1000

  return {
    "sequence": sequence,
    "phase": phase,
    "timestamp": started_at.isoformat(),
    "latency_ms": elapsed_ms,
    "status": status,
    "error": error,
  }


def summarize(results: List[Dict[str, object]], phase: str) -> Optional[Dict[str, float]]:
  phase_values = [r["latency_ms"] for r in results if r["phase"] == phase and not r["error"]]
  if not phase_values:
    return None

  ordered = sorted(phase_values)
  return {
    "count": float(len(ordered)),
    "avg_ms": mean(ordered),
    "p50_ms": percentile(ordered, 0.5),
    "p95_ms": percentile(ordered, 0.95),
    "min_ms": ordered[0],
    "max_ms": ordered[-1],
  }


def main() -> None:
  args = parse_args()
  results: List[Dict[str, object]] = []
  sequence = 1

  for wait_seconds in args.cold_start_waits:
    if wait_seconds > 0:
      print(f"Waiting {wait_seconds}s before cold-start probe {sequence}...")
      time.sleep(wait_seconds)
    results.append(probe(args.url, args.timeout, "cold-start", sequence))
    sequence += 1

  for index in range(args.warm_requests):
    if index > 0 and args.idle_between > 0:
      time.sleep(args.idle_between)
    results.append(probe(args.url, args.timeout, "warm", sequence))
    sequence += 1

  if args.burst_requests > 0:
    print(
      f"\nBursting {args.burst_requests} requests with concurrency {args.burst_concurrency}..."
    )
    with concurrent.futures.ThreadPoolExecutor(
      max_workers=args.burst_concurrency
    ) as executor:
      futures = []
      for _ in range(args.burst_requests):
        futures.append(
          executor.submit(probe, args.url, args.timeout, "burst", sequence)
        )
        sequence += 1
      for future in concurrent.futures.as_completed(futures):
        results.append(future.result())

  cold_summary = summarize(results, "cold-start")
  warm_summary = summarize(results, "warm")
  burst_summary = summarize(results, "burst")

  print("\nPer-request results:")
  for entry in sorted(results, key=lambda r: r["sequence"]):
    status_display = entry["status"] if entry["status"] else "n/a"
    error_display = f" error={entry['error']}" if entry["error"] else ""
    latency_display = f"{entry['latency_ms']:.2f}ms"
    print(
      f"#{entry['sequence']:02d} {entry['phase']:>10} {latency_display:>12} status={status_display}{error_display}"
    )

  print("\nSummaries:")
  if cold_summary:
    print(
      f"Cold starts: count={int(cold_summary['count'])} "
      f"avg={cold_summary['avg_ms']:.2f}ms p50={cold_summary['p50_ms']:.2f}ms "
      f"p95={cold_summary['p95_ms']:.2f}ms min={cold_summary['min_ms']:.2f}ms "
      f"max={cold_summary['max_ms']:.2f}ms"
    )
  else:
    print("Cold starts: no successful samples")

  if warm_summary:
    print(
      f"Warm:       count={int(warm_summary['count'])} "
      f"avg={warm_summary['avg_ms']:.2f}ms p50={warm_summary['p50_ms']:.2f}ms "
      f"p95={warm_summary['p95_ms']:.2f}ms min={warm_summary['min_ms']:.2f}ms "
      f"max={warm_summary['max_ms']:.2f}ms"
    )
  else:
    print("Warm:       no successful samples")

  if args.burst_requests > 0:
    if burst_summary:
      print(
        f"Burst:      count={int(burst_summary['count'])} "
        f"avg={burst_summary['avg_ms']:.2f}ms p50={burst_summary['p50_ms']:.2f}ms "
        f"p95={burst_summary['p95_ms']:.2f}ms min={burst_summary['min_ms']:.2f}ms "
        f"max={burst_summary['max_ms']:.2f}ms"
      )
    else:
      print("Burst:      no successful samples")

  if args.output_json:
    output = {
      "url": args.url,
      "cold_start_waits": args.cold_start_waits,
      "warm_requests": args.warm_requests,
      "idle_between": args.idle_between,
      "timeout": args.timeout,
      "results": results,
      "summaries": {"cold-start": cold_summary, "warm": warm_summary, "burst": burst_summary},
    }
    with open(args.output_json, "w", encoding="utf-8") as handle:
      json.dump(output, handle, indent=2)
    print(f"\nWrote detailed results to {args.output_json}")


if __name__ == "__main__":
  main()

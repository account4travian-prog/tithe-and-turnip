"""GPU thermal guard (stdlib only) - nvidia-smi based cooldown for the asset pipeline.

GTX 1070 context: the card throttles itself near 83 C and its absolute max is
94 C, so the defaults here (never start above 78 C, cool to 62 C) are
conservative quality-of-life limits, not emergency protection.
"""

import subprocess
import time


def temp_c() -> float:
    """Read current GPU temperature via nvidia-smi (no admin needed)."""
    out = subprocess.run(
        ["nvidia-smi", "--query-gpu=temperature.gpu", "--format=csv,noheader,nounits"],
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    if out.returncode != 0:
        raise RuntimeError("nvidia-smi temperature query failed: " + out.stderr.strip())
    return float(out.stdout.strip().splitlines()[0])


def wait_until_cool(cool_below: float, max_temp: float, check_every: float = 10.0, log=print) -> float:
    """Block until GPU temp <= cool_below; warn (but still wait) while above max_temp."""
    while True:
        t = temp_c()
        if t <= cool_below:
            return t
        if t > max_temp:
            log(f"[gpu_guard] {t:.0f}C above max {max_temp:.0f}C - cooling down...")
        else:
            log(f"[gpu_guard] {t:.0f}C - cooling toward {cool_below:.0f}C...")
        time.sleep(check_every)


if __name__ == "__main__":
    print("current GPU temp:", temp_c(), "C")

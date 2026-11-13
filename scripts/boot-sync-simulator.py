"""Start an explicitly selected available iOS simulator; retain bounded CI boot diagnostics."""
import json
import os
import subprocess
from pathlib import Path

out = Path('build')
out.mkdir(exist_ok=True)

def run(args, timeout=30, check=True):
    print('+ ' + ' '.join(args), flush=True)
    return subprocess.run(args, timeout=timeout, check=check)

try:
    listing = subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', 'available', '-j'], timeout=60)
    devices = json.loads(listing)['devices']
    runtimes = sorted((k for k in devices if '.iOS-' in k),
                      key=lambda k: tuple(map(int, k.split('.iOS-')[1].split('-'))), reverse=True)
    requested = os.environ.get('EMA_SIMULATOR_RUNTIME', 'iOS-26-2')
    selected = [r for r in runtimes if r.endswith('.' + requested)]
    if not selected:
        raise RuntimeError(f'Requested simulator {requested} unavailable; available: {runtimes}')
    runtime, device = next((r, d) for r in selected for d in devices[r] if 'iPhone' in d['name'])
    identifier = device['udid']
    print(f"Selected {runtime}: {device['name']} ({identifier})", flush=True)
    # A visible Simulator process also initializes the GUI services used by SpringBoard.
    run(['open', '-a', 'Simulator', '--args', '-CurrentDeviceUDID', identifier])
    run(['xcrun', 'simctl', 'boot', identifier], timeout=90, check=False)
    run(['xcrun', 'simctl', 'bootstatus', identifier, '-b'], timeout=300)
    (out / 'simulator-id').write_text(identifier)
except Exception:
    try:
        diagnostic = subprocess.check_output(['xcrun', 'simctl', 'list', '-j'], timeout=30)
        (out / 'simulator-diagnostics.json').write_bytes(diagnostic)
    except Exception as error:
        print(f'Diagnostics unavailable: {error}', flush=True)
    raise

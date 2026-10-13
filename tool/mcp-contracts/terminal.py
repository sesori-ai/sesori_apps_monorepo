"""POSIX pseudo-terminal for testing the harness's interactive login command."""
import errno
import os
import pty
import select
import signal
import subprocess
import sys


master, slave = pty.openpty()
child = subprocess.Popen(sys.argv[1:], stdin=slave, stdout=slave, stderr=slave)
os.close(slave)
signal.signal(signal.SIGTERM, lambda *_: sys.exit(143))
try:
    while child.poll() is None:
        ready, _, _ = select.select([master, sys.stdin], [], [], 1)
        for source in ready:
            if source == master:
                try:
                    data = os.read(master, 65536)
                except OSError as error:
                    if error.errno == errno.EIO:
                        break
                    raise
                sys.stdout.buffer.write(data)
                sys.stdout.buffer.flush()
            else:
                data = os.read(sys.stdin.fileno(), 65536)
                if not data:
                    sys.exit(143)
                os.write(master, data)
    sys.exit(child.wait())
finally:
    if child.poll() is None:
        child.terminate()
        try:
            child.wait(timeout=1)
        except subprocess.TimeoutExpired:
            child.kill()
            child.wait()
    os.close(master)

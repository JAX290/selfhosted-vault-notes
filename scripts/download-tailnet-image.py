"""Download a public image archive through a userspace Tailscale TCP connection."""
import hashlib
import http.client
import pathlib
import shutil
import subprocess
import sys

peer, host, path, output, expected = sys.argv[1:]
proc = subprocess.Popen(
    ['docker', 'exec', '-i', 'tailscale', 'tailscale', 'nc', peer, '80'],
    stdin=subprocess.PIPE, stdout=subprocess.PIPE,
)
proc.stdin.write(f'GET {path} HTTP/1.0\r\nHost: {host}\r\nConnection: close\r\n\r\n'.encode('ascii'))
proc.stdin.flush()

class ReaderSocket:
    def makefile(self, *args, **kwargs):
        return proc.stdout

response = http.client.HTTPResponse(ReaderSocket())
response.begin()
if response.status != 200:
    proc.terminate()
    raise RuntimeError(f'Download returned HTTP {response.status}')
with pathlib.Path(output).open('wb') as archive:
    shutil.copyfileobj(response, archive)
with pathlib.Path(output).open('rb') as archive:
    digest = hashlib.file_digest(archive, 'sha256').hexdigest()
proc.stdin.close()
proc.wait(timeout=15)
if digest != expected:
    raise RuntimeError('Archive checksum mismatch; refusing import')
print('Archive downloaded and SHA-256 verified')

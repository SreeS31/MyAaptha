"""Isolated S3-compatible recovery drill. Uses a cached image and synthetic data only."""
import argparse
import base64
from contextlib import contextmanager
import json
import os
import re
from pathlib import Path
import secrets
import shutil
import ssl
import subprocess
import tempfile
import time
from urllib.request import urlopen
from urllib.error import URLError

ROOT = Path(__file__).resolve().parents[1]
IMAGE = "quay.io/minio/minio:latest"


def execute(args, **kwargs):
    result = subprocess.run(args, check=True, capture_output=True, text=True, timeout=60, **kwargs)
    return result.stdout.strip()


@contextmanager
def local_tls(enabled):
    if not enabled:
        yield {}, [], None
        return
    with tempfile.TemporaryDirectory(prefix="myaaptha-s3-tls-") as folder:
        root = Path(folder)
        certs = root / "certs"
        certs.mkdir()
        openssl = shutil.which("openssl") or "C:/Program Files/Git/usr/bin/openssl.exe"
        execute([openssl, "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
                 "-subj", "/CN=localhost", "-addext", "subjectAltName=DNS:localhost,IP:127.0.0.1",
                 "-keyout", str(certs / "private.key"), "-out", str(certs / "public.crt")])
        execute(["keytool", "-importcert", "-noprompt", "-alias", "disposable-object-store",
                 "-file", str(certs / "public.crt"), "-keystore", str(root / "trust.p12"),
                 "-storetype", "PKCS12", "-storepass", "disposable-drill-only"])
        options = '\"-Djavax.net.ssl.trustStore=' + str(root / "trust.p12") + '\" -Djavax.net.ssl.trustStorePassword=disposable-drill-only'
        yield {"JAVA_TOOL_OPTIONS": options, "MINIO_KMS_SECRET_KEY": "synthetic-master:" + base64.b64encode(secrets.token_bytes(32)).decode()}, ["-v", str(certs) + ":/certs:ro"], ssl.create_default_context(cafile=str(certs / "public.crt"))


@contextmanager
def disposable_store(tls=False):
    image_id = execute(["docker", "image", "inspect", IMAGE, "--format", "{{.Id}}"])
    if not re.fullmatch(r"sha256:[a-f0-9]{64}", image_id):
        raise ValueError("A cached immutable image identity is required")
    suffix = secrets.token_hex(6)
    name = "myaaptha-s3-drill-" + suffix
    bucket = "myaaptha-drill-" + suffix
    env = {key: value for key, value in os.environ.items()
           if not key.startswith(("AWS_", "MINIO_")) and key not in ("JAVA_TOOL_OPTIONS", "JDK_JAVA_OPTIONS", "_JAVA_OPTIONS", "MAVEN_OPTS")}
    env.update(MINIO_ROOT_USER="drill" + secrets.token_hex(6), MINIO_ROOT_PASSWORD=secrets.token_hex(24), MINIO_BROWSER="off")
    with local_tls(tls) as (tls_env, mounts, health_context):
        env.update(tls_env)
        created = False
        try:
            execute(["docker", "create", "--name", name, "-p", "127.0.0.1::9000",
                     "-e", "MINIO_ROOT_USER", "-e", "MINIO_ROOT_PASSWORD", "-e", "MINIO_BROWSER",
                     *mounts, *(["-e", "MINIO_KMS_SECRET_KEY"] if tls else []),
                     image_id, "server", "/data", "--address", ":9000", *(["--certs-dir", "/certs"] if tls else [])], env=env)
            created = True
            execute(["docker", "start", name])
            mapping = execute(["docker", "port", name, "9000/tcp"])
            host, separator, port = mapping.rpartition(":")
            if host != "127.0.0.1" or not separator or not port.isdigit() or not 1024 <= int(port) <= 65535:
                raise ValueError("Disposable storage must bind only to localhost")
            endpoint = ("https" if tls else "http") + "://127.0.0.1:" + port
            for attempt in range(60):
                try:
                    with urlopen(endpoint + "/minio/health/ready", timeout=2, context=health_context) as response:
                        if response.status == 200:
                            break
                except OSError:
                    pass
                time.sleep(.5)
            else:
                raise RuntimeError("Disposable storage did not become ready")
            if tls:
                try:
                    with urlopen(endpoint + "/minio/health/ready", timeout=2, context=ssl.create_default_context()):
                        raise RuntimeError("Untrusted disposable certificate was unexpectedly accepted")
                except URLError as error:
                    if not isinstance(error.reason, ssl.SSLCertVerificationError):
                        raise RuntimeError("Expected a certificate-validation rejection") from None
                env["MYAAPTHA_S3_DRILL_UNTRUSTED_TLS_REJECTED"] = "true"
            env.update(AWS_ACCESS_KEY_ID=env["MINIO_ROOT_USER"], AWS_SECRET_ACCESS_KEY=env["MINIO_ROOT_PASSWORD"],
                       AWS_EC2_METADATA_DISABLED="true", AWS_REGION="us-east-1", AWS_DEFAULT_REGION="us-east-1",
                       MYAAPTHA_S3_DRILL_TLS=str(tls).lower(), MYAAPTHA_S3_DRILL_ENDPOINT=endpoint, MYAAPTHA_S3_DRILL_BUCKET=bucket, MYAAPTHA_S3_DISPOSABLE=bucket)
            yield env, image_id
        finally:
            if created:
                # This name is generated here, never accepted from user input.
                execute(["docker", "rm", "-f", "-v", name])


def run(maven, tls=False):
    with tempfile.TemporaryDirectory(prefix="myaaptha-s3-recovery-") as folder:
        report = Path(folder) / "result.json"
        empty = Path(folder) / "empty-aws-config"
        empty.write_text("", encoding="utf-8")
        with disposable_store(tls) as (env, image_id):
            env.update(MYAAPTHA_S3_DRILL_REPORT=str(report), AWS_SHARED_CREDENTIALS_FILE=str(empty), AWS_CONFIG_FILE=str(empty))
            result = subprocess.run([str(maven), "-o", "--batch-mode", "-Dtest=S3MediaRecoveryDrillTest",
                                     "-Dmyaaptha.s3.drill=true", "test"], cwd=ROOT / "backend/spring-boot-app",
                                    env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=600)
            print(result.stdout, end="")
            if result.returncode:
                raise RuntimeError("S3 recovery integration test failed")
            proof = json.loads(report.read_text(encoding="utf-8"))
            required = ("unsignedReadDenied", "adapterLoadAndSignedRead", "versionedDeleteMarker", "restoredBytesMatch",
                        "syntheticVersionsPurged", "lifecycleConfigurationRoundTrip")
            if not isinstance(proof, dict) or proof.get("serverSideEncryptionExercised") is not tls or proof.get("releaseApproved") is not False or not all(proof.get(key) is True for key in required):
                raise ValueError("Incomplete integration evidence")
        # Cleanup must succeed before returning success.
        proof.update(untrustedTlsRejected=tls and env.get("MYAAPTHA_S3_DRILL_UNTRUSTED_TLS_REJECTED") == "true", transportTls=tls, imageId=image_id, service="disposable localhost S3-compatible storage", externalServicesContacted=False,
                     customerDataUsed=False, disposableServiceRemoved=True, productionLifecycleAccepted=False)
        return proof


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--maven", type=Path, default=Path(shutil.which("mvn.cmd") or shutil.which("mvn") or "C:/opt/maven/apache-maven-3.9.9/bin/mvn.cmd"))
    parser.add_argument("--tls", action="store_true", help="Use a trusted disposable TLS endpoint and synthetic SSE-S3 master key.")
    args = parser.parse_args()
    try:
        proof = run(args.maven, args.tls)
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError):
        parser.exit(1, "S3 recovery drill failed; inspect its local test output. No production acceptance granted.\n")
    print("S3_RECOVERY_RESULT=" + json.dumps(proof, sort_keys=True))

import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest


SOURCE = Path(__file__).resolve().parent


class MaintenanceTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.env = os.environ | {
            "HOME": str(self.root / "home"),
            "XDG_STATE_HOME": str(self.root / "state"),
            "PATH": str(self.bin) + os.pathsep + os.environ["PATH"],
            "REPO": str(self.root / "repo"),
            "CIX_REPOS_OWNER": "test-owner",
            "CIX_REPOS_DEST": str(self.root / "mirrors"),
        }
        Path(self.env["HOME"]).mkdir()

    def stub(self, name, text):
        path = self.bin / name
        path.write_text(f"#!{shutil.which('bash')}\nset -eu\n" + text)
        path.chmod(0o755)

    def run_script(self, name, *arguments):
        source = (SOURCE / "ui.sh").read_text() + "\n" + (SOURCE / name).read_text()
        return subprocess.run(["bash", "-c", source, name, *arguments], env=self.env,
                              capture_output=True, text=True)

    def git(self, *arguments):
        return subprocess.run(["git", *map(str, arguments)], env=self.env,
                              capture_output=True, text=True, check=True).stdout.strip()

    def repositories(self):
        origin = self.root / "origin"
        self.git("init", "--initial-branch=main", origin)
        self.git("-C", origin, "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
                 "commit", "--allow-empty", "-m", "initial")
        self.stub("gh", 'printf "sample.repo\\t%s\\tPRIVATE\\n" "$TEST_ORIGIN"\n')
        self.env["TEST_ORIGIN"] = str(origin)
        return origin

    def test_removed_upstream_branch_remains_recoverable(self):
        origin = self.repositories()
        self.git("-C", origin, "branch", "retained")
        first = self.run_script("repos", "backup", "--no-push")
        self.assertEqual(first.returncode, 0, first.stderr)
        self.git("-C", origin, "branch", "-D", "retained")
        second = self.run_script("repos", "backup", "--no-push")
        self.assertEqual(second.returncode, 0, second.stderr)
        mirror = Path(self.env["CIX_REPOS_DEST"]) / "sample.repo.git"
        self.git("-C", mirror, "show-ref", "--verify", "refs/heads/retained")

    def test_unknown_repository_fails_before_backing_up_anything(self):
        self.repositories()
        result = self.run_script("repos", "backup", "--no-push", "sampleXrepo")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unknown repository", result.stderr)
        self.assertFalse((Path(self.env["CIX_REPOS_DEST"]) / "sample.repo.git").exists())

    def test_model_fetch_serializes_shared_partial_file(self):
        payload = b"test model\n"
        self.env.update({
            "MODEL_DIR": str(self.root / "models"),
            "MODEL_FILE": "test-model",
            "MODEL_SHA256": hashlib.sha256(payload).hexdigest(),
            "MODEL_REPO": "test/model",
            "MODEL_REV": "test-revision",
            "TEST_DOWNLOADS": str(self.root / "downloads"),
        })
        self.stub("curl", '''while [[ $# -gt 0 ]]; do
  if [[ $1 == -o ]]; then output=$2; shift; fi
  shift
done
printf 'start\\n' >> "$TEST_DOWNLOADS"
sleep 0.2
printf 'test model\\n' > "$output"
''')
        script = (SOURCE / "ui.sh").read_text() + "\n" + (SOURCE.parent / "llm/cix-llm").read_text()
        with subprocess.Popen(["bash", "-c", script, "llm", "fetch"], env=self.env,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) as first:
            deadline = time.monotonic() + 5
            while not Path(self.env["TEST_DOWNLOADS"]).exists():
                if first.poll() is not None or time.monotonic() >= deadline:
                    self.fail("first model fetch never started")
                time.sleep(0.01)
            second = subprocess.run(["bash", "-c", script, "llm", "fetch"], env=self.env,
                                    capture_output=True, text=True)
            _, error = first.communicate(timeout=5)
        self.assertEqual(first.returncode, 0, error)
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertEqual(Path(self.env["TEST_DOWNLOADS"]).read_text(), "start\n")
        self.assertEqual((Path(self.env["MODEL_DIR"]) / "test-model").read_bytes(), payload)

    def backup_key(self):
        identity = Path(self.env["HOME"]) / ".config/agenix/identity.txt"
        identity.parent.mkdir(parents=True)
        with identity.open("w") as output:
            subprocess.run(["age-keygen"], stdout=output, stderr=subprocess.DEVNULL, check=True)
        public = subprocess.run(["age-keygen", "-y", str(identity)],
                                capture_output=True, text=True, check=True).stdout
        host = subprocess.check_output(["hostname"], text=True).strip()
        destination = Path(self.env["REPO"]) / "secrets" / (host + ".pub")
        destination.parent.mkdir(parents=True)
        destination.write_text(public)
        ssh_identity = Path(self.env["HOME"]) / ".ssh/id_ed25519"
        ssh_identity.parent.mkdir()
        subprocess.run(["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", str(ssh_identity)],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
        self.env["TEST_SSH_IDENTITY"] = str(ssh_identity)
        self.env["TEST_SSH_TITLE"] = host + " SSH key"
        self.env["TEST_IDENTITY"] = str(identity)
        self.env["TEST_TITLE"] = host + " agenix recovery key"
        self.stub("op", '''case "$1 $2" in
  "vault list") exit 0 ;;
  "item list") jq -n --arg age "$TEST_TITLE" --arg ssh "$TEST_SSH_TITLE" '[{title:$age},{title:$ssh}]' ;;
  "document get")
    if [[ $3 == "$TEST_TITLE" ]]; then cat "$TEST_IDENTITY"; else cat "$TEST_SSH_IDENTITY"; fi ;;

  *) exit 1 ;;
esac
''')
        return destination

    def test_backup_verifies_real_disposable_age_key(self):
        self.backup_key()
        result = self.run_script("backup", "--check")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("verified", result.stdout)

    def test_empty_public_key_and_failed_download_cannot_verify(self):
        public = self.backup_key()
        public.write_text("")
        self.stub("op", '''case "$1 $2" in
  "vault list") exit 0 ;;
  "item list") jq -n --arg title "$TEST_TITLE" '[{title:$title}]' ;;
  *) exit 1 ;;
esac
''')
        result = self.run_script("backup", "--check")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(line.startswith("verified") and self.env["TEST_TITLE"] in line
                             for line in result.stdout.splitlines()))
        state = Path(self.env["XDG_STATE_HOME"]) / "cix/backups"
        self.assertEqual(state.read_text(), "")

    def test_auto_check_rejects_private_key_changed_after_verification(self):
        self.backup_key()
        self.assertEqual(self.run_script("backup", "--check").returncode, 0)
        Path(self.env["TEST_IDENTITY"]).write_text("invalid disposable key\n")
        result = self.run_script("backup", "--auto", "--check")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("local private and public keys do not match", result.stdout)

    def test_auto_check_rejects_missing_key_pair_after_verification(self):
        public = self.backup_key()
        self.assertEqual(self.run_script("backup", "--check").returncode, 0)
        public.unlink()
        Path(self.env["TEST_IDENTITY"]).unlink()
        result = self.run_script("backup", "--auto", "--check")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("private or public key is missing", result.stdout)

    def test_check_rejects_half_present_key_pair(self):
        public = self.backup_key()
        for missing in [public, Path(self.env["TEST_IDENTITY"])]:
            with self.subTest(missing=missing.name):
                contents = missing.read_bytes()
                missing.unlink()
                result = self.run_script("backup", "--check")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("private or public key is missing", result.stdout)
                missing.write_bytes(contents)

    def test_failed_download_cannot_verify_valid_local_key(self):
        self.backup_key()
        self.stub("op", '''case "$1 $2" in
  "vault list") exit 0 ;;
  "item list") jq -n --arg title "$TEST_TITLE" '[{title:$title}]' ;;
  *) exit 1 ;;
esac
''')
        result = self.run_script("backup", "--check")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(line.startswith("verified") and self.env["TEST_TITLE"] in line
                             for line in result.stdout.splitlines()))


if __name__ == "__main__":
    unittest.main()

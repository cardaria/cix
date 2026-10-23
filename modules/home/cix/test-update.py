"""Exercise the update workflow with fake Nix/sudo and real Git/flock.

All system/store paths in the script under test are redirected into a temporary
sandbox. The mocks never invoke Nix, sudo, systemd, or a bootloader.
"""

import fcntl
import json
import os
import shutil
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parent
MOCK = r'''import json, os, pathlib, signal, sys
p = pathlib.Path
root = p(os.environ['CASE_ROOT'])
name = p(sys.argv[0]).name
args = sys.argv[1:]
with (root / 'calls').open('a') as f:
    f.write(json.dumps([name, *args]) + '\n')
fail = os.environ.get('FAIL', '')
if name == 'hostname':
    print('draba')
elif name == 'cix-update-pve':
    pass
elif name == 'cix-backup':
    assert args == ['--auto', '--check'], args
    sys.exit(1 if fail == 'backups' else 0)
elif name == 'sudo':
    assert args == ['nixos-rebuild', 'boot', '--store-path', str(root / 'store/candidate'), '--no-reexec'], args
    if fail != 'profile':
        (root / 'profile').unlink()
        (root / 'profile').symlink_to(root / 'store/candidate')
    if fail in ('boot', 'interrupt'):
        print('simulated boot installation failure')
        sys.exit(130 if fail == 'interrupt' else 4)
elif name == 'nix':
    action = ' '.join(args[:2])
    if fail == {'flake update':'inputs', 'flake metadata':'snapshot', 'flake check':'checks', 'store diff-closures':'changes'}.get(action):
        sys.exit(42)
    if action == 'flake metadata':
        assert '--no-update-lock-file' in args, args
        if fail == 'bad-metadata':
            print('{}')
            sys.exit(0)
        print(json.dumps({'path': str(root / 'store/source')}))
    elif action == 'flake check':
        assert '--no-update-lock-file' in args, args
        assert args[2] == str(root / 'store/source'), args
    elif args[0] == 'eval':
        print(json.dumps(['edge', 'gamma']))
    elif args[0] == 'build':
        assert '--no-update-lock-file' in args, args
        assert args[1] == str(root / 'store/source') + '#nixosConfigurations.draba.config.system.build.toplevel', args
        if fail == 'build':
            sys.exit(42)
        if fail == 'hangup':
            os.kill(os.getppid(), signal.SIGHUP)
            sys.exit(0)
        if fail == 'bad-result':
            sys.exit(0)
        p(args[args.index('--out-link') + 1]).symlink_to(root / 'store/candidate')
        if fail == 'drift':
            (root / 'profile').unlink()
            (root / 'profile').symlink_to(root / 'store/other')
        if fail == 'drift-current':
            (root / 'current').unlink()
            (root / 'current').symlink_to(root / 'store/other')
    elif action not in ('flake update', 'store diff-closures'):
        raise AssertionError(args)
else:
    raise AssertionError(name)
'''


class Update(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.repo = self.root / 'repo'
        self.repo.mkdir()
        self.git('init', '-q')
        (self.repo / 'flake.nix').write_text('{}\n')
        (self.repo / 'flake.lock').write_text('{}\n')
        self.git('add', 'flake.nix', 'flake.lock')
        self.git('-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '-qm', 'fixture')
        for name in ('candidate', 'previous', 'other', 'source', 'previous-display-5090'):
            target = self.root / 'store' / name
            (target / 'bin').mkdir(parents=True)
            (target / 'flake.nix').write_text('{}\n')
            executable = target / 'bin/switch-to-configuration'
            executable.write_text('#!/bin/sh\nexit 99\n')
            executable.chmod(0o755)
        for name in ('current', 'profile'):
            (self.root / name).symlink_to(self.root / 'store/previous')
        bindir = self.root / 'bin'
        bindir.mkdir()
        mock = bindir / 'mock'
        mock.write_text(f'#!{sys.executable}\n' + MOCK)
        mock.chmod(0o755)
        for name in ('nix', 'sudo', 'hostname', 'cix-backup', 'cix-update-pve'):
            (bindir / name).symlink_to(mock)
        script = (SOURCE / 'ui.sh').read_text() + (SOURCE / 'update').read_text()
        script = script.replace('/nix/var/nix/profiles/system', str(self.root / 'profile'))
        script = script.replace('/run/current-system', str(self.root / 'current'))
        script = script.replace('/nix/store/', str(self.root / 'store') + '/')
        self.script = self.root / 'update'
        self.script.write_text(script)
        self.env = dict(os.environ, PATH=f'{bindir}:{os.environ["PATH"]}',
                        REPO=str(self.repo), PVE=str(self.root / 'pve'), CASE_ROOT=str(self.root),
                        XDG_STATE_HOME=str(self.root / 'state'))

    def git(self, *args):
        subprocess.run(['git', '-C', str(self.repo), *args], check=True, capture_output=True)

    def run_update(self, *args, target='draba', reply='y\n', fail=''):
        args = ((target,) if target else ()) + args
        result = subprocess.run(['bash', str(self.script), *args], input=reply, text=True,
                                capture_output=True, env=dict(self.env, FAIL=fail), timeout=15)
        calls = self.root / 'calls'
        self.calls = [json.loads(x) for x in calls.read_text().splitlines()] if calls.exists() else []
        self.output = result.stdout + result.stderr
        return result.returncode

    # Reading the host name or listing the guests changes nothing
    def side_effects(self):
        return [c for c in self.calls if c[0] != 'hostname' and c[:2] != ['nix', 'eval']]

    def no_boot(self):
        self.assertFalse(any(c[0] == 'sudo' for c in self.calls), self.output)

    def test_success(self):
        self.assertEqual(self.run_update(), 0, self.output)
        self.assertIn('Boot installation completed', self.output)
        self.assertEqual((self.root / 'current').resolve(), self.root / 'store/previous')
        self.assertEqual((self.root / 'profile').resolve(), self.root / 'store/candidate')
        self.assertEqual(list((self.root / 'state').glob('cix/updates/run.*/result')), [])

    def test_dry_run(self):
        self.assertEqual(self.run_update('--dry-run'), 0, self.output)
        self.no_boot()
        self.assertEqual(len(list((self.root / 'state').glob('cix/updates/run.*/result'))), 1)

    def test_retry_skips_update(self):
        self.assertEqual(self.run_update('--no-update'), 0, self.output)
        self.assertFalse(any(c[:3] == ['nix', 'flake', 'update'] for c in self.calls))

    def nvidia_utility(self, status):
        binary = self.root / 'store/candidate/sw/bin/nvidia-smi'
        binary.parent.mkdir(parents=True)
        binary.write_text('#!' + shutil.which('bash') + '\n[[ $1 == --help ]] || exit 99\nexit ' + str(status) + '\n')
        binary.chmod(0o755)

    def test_broken_nvidia_utility_blocks_installation(self):
        self.nvidia_utility(139)
        self.assertNotEqual(self.run_update(), 0)
        self.assertIn('candidate NVIDIA utility cannot start', self.output)
        self.no_boot()

    def test_working_nvidia_utility(self):
        self.nvidia_utility(0)
        self.assertEqual(self.run_update(), 0, self.output)

    def test_state_directory_with_spaces(self):
        self.env['XDG_STATE_HOME'] = str(self.root / 'state with spaces')
        self.assertEqual(self.run_update(), 0, self.output)

    def test_bad_metadata(self):
        self.assertNotEqual(self.run_update(fail='bad-metadata'), 0)
        self.assertIn('during snapshot', self.output)
        self.no_boot()

    def test_missing_build_result(self):
        self.assertNotEqual(self.run_update(fail='bad-result'), 0)
        self.assertIn('during build', self.output)
        self.no_boot()

    def test_hangup(self):
        self.assertEqual(self.run_update(fail='hangup'), 129, self.output)
        self.assertIn('during build', self.output)
        self.no_boot()

    def test_concurrent_live_activation(self):
        self.assertNotEqual(self.run_update(fail='drift-current'), 0)
        self.assertIn('changed during this update', self.output)
        self.no_boot()

    def test_cuda(self):
        self.assertEqual(self.run_update('--cuda', '--dry-run'), 0, self.output)
        self.assertTrue(any('nixpkgs-cuda' in c for c in self.calls))

    def test_default_preserves_cuda_pin(self):
        self.run_update('--dry-run')
        self.assertFalse(any('nixpkgs-cuda' in c for c in self.calls))

    def test_invalid_arguments(self):
        for args in [('--bogus',), ('--cuda', '--no-update')]:
            with self.subTest(args=args):
                self.assertNotEqual(self.run_update(*args), 0)
                self.assertEqual(self.side_effects(), [])

    def test_help_has_no_side_effects(self):
        self.assertEqual(self.run_update('--help'), 0)
        self.assertEqual(self.side_effects(), [])

    def changed_nothing(self):
        self.assertFalse(any(c[:3] == ['nix', 'flake', 'update'] or c[:2] == ['nix', 'build'] or c[0] in ('sudo', 'cix-backup')
                             for c in self.calls), self.calls)

    def test_no_target_lists_guests_and_changes_nothing(self):
        self.assertEqual(self.run_update(target=None), 0, self.output)
        self.assertIn('Guests on pve: edge gamma', self.output)
        self.assertTrue(any(c[:2] == ['nix', 'eval'] and str(self.root / 'pve') + '#nixosConfigurations' in c for c in self.calls))
        self.changed_nothing()

    def test_unknown_target_is_refused(self):
        self.assertNotEqual(self.run_update(target='nonsense'), 0)
        self.assertIn("unknown target 'nonsense'", self.output)
        self.changed_nothing()

    def test_guest_targets_go_to_the_pve_update(self):
        for target in ('gamma', 'pve'):
            with self.subTest(target=target):
                (self.root / 'calls').write_text('')
                self.assertEqual(self.run_update('--dry-run', '--no-images', target=target), 0, self.output)
                self.assertEqual(self.side_effects(), [['cix-update-pve', target, '--dry-run', '--no-images']])
                self.changed_nothing()

    def test_two_targets_are_refused(self):
        self.assertNotEqual(self.run_update('gamma'), 0)
        self.changed_nothing()

    def test_decline(self):
        self.assertEqual(self.run_update(reply='n\n'), 0, self.output)
        self.no_boot()

    def test_eof(self):
        self.assertEqual(self.run_update(reply=''), 0, self.output)
        self.no_boot()

    def test_untracked_rejected(self):
        (self.repo / 'new.nix').write_text('{}')
        self.assertNotEqual(self.run_update(), 0)
        self.assertIn('untracked', self.output)
        self.assertEqual(self.side_effects(), [])

    def test_dirty_decline(self):
        (self.repo / 'flake.lock').write_text('{"changed":true}')
        self.assertNotEqual(self.run_update(reply='n\n'), 0)
        self.assertEqual(self.side_effects(), [])

    def test_dirty_accept(self):
        (self.repo / 'flake.lock').write_text('{"changed":true}')
        self.assertEqual(self.run_update(reply='y\ny\n'), 0, self.output)

    def test_failures_stop_before_boot(self):
        for phase in ('backups', 'inputs', 'snapshot', 'checks', 'build', 'changes', 'drift'):
            with self.subTest(phase=phase):
                (self.root / 'calls').write_text('')
                self.assertNotEqual(self.run_update(fail=phase), 0, self.output)
                self.no_boot()
                self.assertIn('during ' + ('changes' if phase == 'drift' else phase), self.output)
                self.assertNotIn('Boot installation completed', self.output)

    def test_boot_failure_reports_partial_state(self):
        self.assertEqual(self.run_update(fail='boot'), 4, self.output)
        self.assertIn('partially updated', self.output)
        self.assertIn(str(self.root / 'store/previous'), self.output)
        self.assertNotIn('Boot installation completed', self.output)

    def test_interrupted_boot(self):
        self.assertEqual(self.run_update(fail='interrupt'), 130, self.output)
        self.assertIn('partially updated', self.output)

    def test_profile_mismatch(self):
        self.assertNotEqual(self.run_update(fail='profile'), 0)
        self.assertIn('does not point to the candidate', self.output)

    def test_same_profile_still_retries_bootloader(self):
        (self.root / 'profile').unlink()
        (self.root / 'profile').symlink_to(self.root / 'store/candidate')
        self.assertEqual(self.run_update(), 0, self.output)
        self.assertTrue(any(c[0] == 'sudo' for c in self.calls))

    def test_specialisation_missing(self):
        (self.root / 'current').unlink()
        (self.root / 'current').symlink_to(self.root / 'store/previous-display-5090')
        self.assertNotEqual(self.run_update(), 0)
        self.assertIn('missing your display-5090', self.output)
        self.no_boot()

    def test_specialisation_present(self):
        target = self.root / 'store/candidate/specialisation'
        target.mkdir()
        (target / 'display-5090').symlink_to(self.root / 'store/previous-display-5090')
        (self.root / 'current').unlink()
        (self.root / 'current').symlink_to(self.root / 'store/previous-display-5090')
        self.assertEqual(self.run_update(), 0, self.output)
        self.assertIn('Keep selecting display-5090', self.output)

    def test_concurrent_update(self):
        with (self.repo / '.git/cix-update.lock').open('w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.assertNotEqual(self.run_update(), 0)
        self.assertIn('Another cix update', self.output)
        self.assertEqual(self.side_effects(), [])


if __name__ == '__main__':
    unittest.main()

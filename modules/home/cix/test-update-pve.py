"""Exercise cix update pve with fake guests: real Git, flock and jq; fake Nix, SSH and registries.

The mocks never reach a machine, a registry or the Nix store. Each guest's running
system is a file in the sandbox that the fake nixos-rebuild rewrites.
"""

import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parent
OLD = 'sha256:' + 'a' * 64
NEW = 'sha256:' + 'b' * 64
GUESTS = {
    # name: address, stage, settle, autoRollback, containers, images
    'alpha': ('192.0.2.5', 50, 300, False, 'pinned', {'tool': f'ghcr.io/x/tool:latest@{OLD}'}),
    'gamma': ('192.0.2.3', 50, 300, False, 'pinned', {'player': f'lscr.io/linuxserver/player:latest@{OLD}'}),
    'beta': ('192.0.2.50', 50, 300, False, 'self-managed', {}),
    'watch': ('192.0.2.2', 80, 300, False, 'pinned', {}),
    'edge': ('192.0.2.1', 90, 90, True, 'pinned', {}),
}
REGISTRY = {
    'host': '192.0.2.200',
    'checks': [
        {'name': 'site', 'host': 'gamma', 'kind': 'proxy', 'target': 'https://site.example/', 'query': None, 'expect': None},
        {'name': 'player', 'host': 'gamma', 'kind': 'http', 'target': 'http://192.0.2.3:32400/identity', 'query': None, 'expect': '200'},
        {'name': 'dns', 'host': 'edge', 'kind': 'dns', 'target': '192.0.2.1', 'query': 'example', 'expect': '192.0.2.1'},
        {'name': 'voice', 'host': 'beta', 'kind': 'tcp', 'target': '192.0.2.50:7881', 'query': None, 'expect': None},
    ],
    'guests': [
        {'name': n, 'address': a, 'stage': s, 'settle': t, 'autoRollback': r, 'containers': c,
         'images': [{'container': k, 'image': v} for k, v in i.items()]}
        for n, (a, s, t, r, c, i) in GUESTS.items()
    ],
}
LOCK = {'nodes': {n: {'locked': {'rev': r * 40, 'lastModified': 1790000000}} for n, r in
                  (('nixpkgs-stable', '1'), ('nixpkgs-pve', '2'))}, 'root': 'root', 'version': 7}

MOCK = r'''import json, os, pathlib, sys
p = pathlib.Path
root = p(os.environ['CASE_ROOT'])
name = p(sys.argv[0]).name
args = sys.argv[1:]
with (root / 'calls').open('a') as f:
    f.write(json.dumps([name, *args]) + '\n')
fail = os.environ.get('FAIL', '').split(',')
registry = json.loads((root / 'registry.json').read_text())
by_address = {g['address']: g['name'] for g in registry['guests']}
NEW = 'sha256:' + 'b' * 64

def running(guest):
    return (root / 'running' / guest).read_text()

def broken():
    # A guest named in fail as broken:<guest> fails the checks while it runs its new build
    return any(f.startswith('broken:') and running(f[7:]) == str(root / 'store' / (f[7:] + '-new')) for f in fail)

if name == 'nix':
    action = ' '.join(args[:2])
    if args[0] == 'eval':
        print((root / 'registry.json').read_text())
    elif action == 'flake update':
        assert args[2:] == ['nixpkgs-stable', 'nixpkgs-pve'], args
        lock = json.loads((p.cwd() / 'flake.lock').read_text())
        lock['nodes']['nixpkgs-pve']['locked'] = {'rev': '3' * 40, 'lastModified': 1790500000}
        (p.cwd() / 'flake.lock').write_text(json.dumps(lock, indent=2) + '\n')
    elif action == 'flake metadata':
        assert '--no-update-lock-file' in args, args
        print(json.dumps({'path': str(root / 'store/source')}))
    elif action == 'flake check':
        assert args[2] == str(root / 'store/source'), args
        sys.exit(42 if 'checks' in fail else 0)
    elif args[0] == 'build':
        guest = args[1].split('#nixosConfigurations.')[1].split('.')[0]
        assert args[1].startswith(str(root / 'store/source') + '#'), args
        if 'build' in fail:
            sys.exit(42)
        p(args[args.index('--out-link') + 1]).symlink_to(root / 'store' / (guest + ('-old' if 'same' in fail else '-new')))
    elif args[0] == 'copy':
        assert args[1] == '--to' and args[2].startswith('ssh-ng://root@'), args
    else:
        raise AssertionError(args)
elif name == 'nix-store':
    assert args[0] == '-qR', args
    print('\n'.join(['/nix/store/' + 'a' * 32 + '-player-1.43.4', '/nix/store/' + 'a' * 32 + '-glibc-2.40']
                    if args[1].endswith('-old') else
                    ['/nix/store/' + 'b' * 32 + '-player-2.0.1', '/nix/store/' + 'b' * 32 + '-glibc-2.40']))
elif name == 'ssh':
    host = next(a for a in args if a.startswith('root@'))[5:]
    command = args[args.index('root@' + host) + 1:]
    guest = by_address.get(host)
    if host == registry['host']:
        print('apt\t1 update · apt full-upgrade\nkernel\t7.0, the newest installed')
    elif command[:2] == ['systemctl', 'list-units']:
        if 'units:' + guest in fail:
            print('broken.service loaded failed failed Broken')
    elif command == ['readlink', '-f', '/run/current-system']:
        print(running(guest))
    elif command[0] == 'nix-store':
        subprocess = __import__('subprocess')
        sys.exit(subprocess.run([str(root / 'bin/nix-store'), *command[1:]]).returncode)
    elif command[:3] == ['docker', 'image', 'inspect']:
        sys.exit(1)
    elif command[:2] == ['docker', 'pull']:
        pass
    else:
        raise AssertionError(args)
elif name == 'nixos-rebuild':
    assert args[0] == 'switch' and args[1] == '--store-path' and args[3] == '--target-host', args
    guest = by_address[args[4][5:]]
    if 'switch:' + guest in fail:
        sys.exit(4)
    (root / 'running' / guest).write_text(args[2])
elif name == 'skopeo':
    if args[0] == 'manifest-digest':
        sys.stdin.read()
        print(os.environ.get('DIGEST', NEW))
    elif args[:3] == ['inspect', '--retry-times', '2'] and args[3] == '--raw':
        print('{}')
    elif args[:3] == ['inspect', '--retry-times', '2'] and args[3] == '--format':
        old = args[-1].endswith('a' * 64)
        print('latest' if 'samelabel' in fail else ('1.43.4' if old else ('2.0.1' if 'major' in fail else '1.43.5')))
    else:
        raise AssertionError(args)
elif name == 'curl':
    unhealthy = 'unhealthy' in fail or broken()
    print('000' if unhealthy else '200', end='')
    sys.exit(7 if unhealthy else 0)
elif name == 'dig':
    print('192.0.2.1')
elif name in ('timeout', 'sleep'):
    pass
else:
    raise AssertionError(name)
'''


class UpdatePve(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / 'registry.json').write_text(json.dumps(REGISTRY))
        self.repo = self.root / 'repo'
        (self.repo / 'hosts').mkdir(parents=True)
        self.git('init', '-q')
        (self.repo / 'flake.nix').write_text('{}\n')
        (self.repo / 'flake.lock').write_text(json.dumps(LOCK, indent=2) + '\n')
        for guest, (_, _, _, _, _, images) in GUESTS.items():
            lines = ''.join(f'  {c}.image = "{i}";\n' for c, i in images.items())
            (self.repo / 'hosts' / f'{guest}.nix').write_text('{\n' + lines + '}\n')
        self.git('add', '.')
        self.git('-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '-qm', 'fixture')
        (self.root / 'store/source').mkdir(parents=True)
        (self.root / 'store/source/flake.nix').write_text('{}\n')
        (self.root / 'running').mkdir()
        for guest in GUESTS:
            for kind in ('old', 'new'):
                target = self.root / 'store' / f'{guest}-{kind}' / 'bin'
                target.mkdir(parents=True)
                (target / 'switch-to-configuration').write_text('#!/bin/sh\nexit 99\n')
                (target / 'switch-to-configuration').chmod(0o755)
            (self.root / 'running' / guest).write_text(str(self.root / 'store' / f'{guest}-old'))
        bindir = self.root / 'bin'
        bindir.mkdir()
        mock = bindir / 'mock'
        mock.write_text(f'#!{sys.executable}\n' + MOCK)
        mock.chmod(0o755)
        for name in ('nix', 'nix-store', 'ssh', 'nixos-rebuild', 'skopeo', 'curl', 'dig', 'timeout', 'sleep'):
            (bindir / name).symlink_to(mock)
        script = (SOURCE / 'steps.sh').read_text() + (SOURCE / 'update-pve').read_text()
        script = script.replace('/nix/store/', str(self.root / 'store') + '/')
        self.script = self.root / 'update-pve'
        self.script.write_text(script)
        self.env = dict(os.environ, PATH=f'{bindir}:{os.environ["PATH"]}',
                        REPO=str(self.repo), CASE_ROOT=str(self.root),
                        XDG_STATE_HOME=str(self.root / 'state'))

    def git(self, *args):
        return subprocess.run(['git', '-C', str(self.repo), *args], check=True, capture_output=True, text=True).stdout

    def run_update(self, target='pve', *args, reply='y\n', fail='', digest=None):
        env = dict(self.env, FAIL=fail)
        if digest:
            env['DIGEST'] = digest
        result = subprocess.run(['bash', str(self.script), target, *args], input=reply, text=True,
                                capture_output=True, env=env, timeout=30, cwd=self.repo)
        calls = self.root / 'calls'
        self.calls = [json.loads(x) for x in calls.read_text().splitlines()] if calls.exists() else []
        self.output = result.stdout + result.stderr
        return result.returncode

    def running(self, guest):
        return Path((self.root / 'running' / guest).read_text()).name

    def deploys(self):
        return [c[5][5:] for c in self.calls if c[0] == 'nixos-rebuild']

    def addresses(self, *guests):
        return ['root@' + GUESTS[g][0] for g in guests]

    def pin(self, guest):
        return (self.repo / 'hosts' / f'{guest}.nix').read_text()

    def test_success_deploys_by_stage_gateway_last(self):
        self.assertEqual(self.run_update(), 0, self.output)
        order = ['alpha', 'beta', 'gamma', 'watch', 'edge']
        self.assertEqual(self.deploys(), [GUESTS[g][0] for g in order])
        for guest in order:
            self.assertEqual(self.running(guest), f'{guest}-new')
        self.assertIn('Updated alpha beta gamma watch edge', self.output)

    def test_everything_lands_before_the_first_deploy(self):
        self.run_update()
        first = next(i for i, c in enumerate(self.calls) if c[0] == 'nixos-rebuild')
        copies = [i for i, c in enumerate(self.calls) if c[:2] == ['nix', 'copy']]
        pulls = [i for i, c in enumerate(self.calls) if c[0] == 'ssh' and 'pull' in c]
        self.assertEqual(len(copies), 5)
        self.assertEqual(len(pulls), 2)
        self.assertTrue(all(i < first for i in copies + pulls))

    def test_pins_follow_their_tag(self):
        self.assertEqual(self.run_update(), 0, self.output)
        self.assertIn(f'player:latest@{NEW}', self.pin('gamma'))
        self.assertIn(f'tool:latest@{NEW}', self.pin('alpha'))
        self.assertRegex(self.output, r'player +1\.43\.4 → 1\.43\.5')
        self.assertEqual(json.loads((self.repo / 'flake.lock').read_text())['nodes']['nixpkgs-pve']['locked']['rev'], '3' * 40)

    def test_package_changes_are_listed_and_major_jumps_flagged(self):
        self.run_update(fail='major', reply='n\n')
        self.assertRegex(self.output, r'player +1\.43\.4 → 2\.0\.1  major')
        self.assertIn('Major version jumps', self.output)
        self.assertRegex(self.output, r'gamma +player +1\.43\.4 → 2\.0\.1')
        self.assertNotIn('glibc', self.output)

    def test_uninformative_labels_show_the_digests(self):
        self.run_update('gamma', fail='samelabel', reply='n\n')
        self.assertRegex(self.output, r'player +latest aaaaaaaaaaaa → latest bbbbbbbbbbbb')

    def test_dry_run_deploys_nothing(self):
        self.assertEqual(self.run_update('pve', '--dry-run'), 0, self.output)
        self.assertEqual(self.deploys(), [])
        self.assertFalse(any(c[:2] == ['nix', 'copy'] or 'pull' in c for c in self.calls))
        self.assertIn('Dry run', self.output)

    def test_decline_deploys_nothing(self):
        self.assertEqual(self.run_update(reply='n\n'), 0, self.output)
        self.assertEqual(self.deploys(), [])
        self.assertFalse(any(c[:2] == ['nix', 'copy'] for c in self.calls))

    def test_eof_deploys_nothing(self):
        self.assertEqual(self.run_update(reply=''), 0, self.output)
        self.assertEqual(self.deploys(), [])

    def test_one_guest(self):
        self.assertEqual(self.run_update('gamma'), 0, self.output)
        self.assertEqual(self.deploys(), [GUESTS['gamma'][0]])
        self.assertEqual(self.running('alpha'), 'alpha-old')
        self.assertIn(OLD, self.pin('alpha'))
        self.assertIn('other guests take them at their next deploy', self.output)
        self.assertNotIn('Proxmox host', self.output)
        self.assertFalse(any(c[0] == 'nix' and c[1] == 'build' and '.alpha.' in c[2] for c in self.calls))

    def test_host_is_reported_for_pve_only(self):
        self.run_update(reply='n\n')
        self.assertIn('1 update · apt full-upgrade', self.output)
        self.assertIn('you update it yourself', self.output)

    def test_unhealthy_start_is_refused(self):
        self.assertNotEqual(self.run_update(fail='unhealthy'), 0)
        self.assertIn('already unhealthy', self.output)
        self.assertIn('Failing checks: player site', self.output)
        self.assertFalse(any(c[:3] == ['nix', 'flake', 'update'] for c in self.calls))
        self.assertEqual(self.deploys(), [])

    def test_failed_unit_at_start_is_refused(self):
        self.assertNotEqual(self.run_update(fail='units:watch'), 0)
        self.assertIn('Failed units on watch', self.output)
        self.assertFalse(any(c[:3] == ['nix', 'flake', 'update'] for c in self.calls))

    def test_broken_guest_stops_the_run(self):
        self.assertNotEqual(self.run_update(fail='broken:gamma'), 0)
        self.assertEqual(self.deploys(), [GUESTS[g][0] for g in ('alpha', 'beta', 'gamma')])
        self.assertEqual(self.running('gamma'), 'gamma-new')
        self.assertEqual(self.running('edge'), 'edge-old')
        self.assertIn('nixos-rebuild switch --store-path ' + str(self.root / 'store/gamma-old'), self.output)

    def test_failed_switch_stops_the_run(self):
        self.assertNotEqual(self.run_update(fail='switch:alpha'), 0)
        self.assertEqual(self.deploys(), [GUESTS['alpha'][0]])
        self.assertIn('Return it to the one it ran before', self.output)

    def test_broken_gateway_rolls_back_by_itself(self):
        self.assertNotEqual(self.run_update(fail='broken:edge'), 0)
        self.assertEqual(self.deploys()[-2:], [GUESTS['edge'][0]] * 2)
        self.assertEqual(self.running('edge'), 'edge-old')
        self.assertIn('back on its previous build and healthy', self.output)
        self.assertNotIn('Return it to the one it ran before', self.output)

    def test_up_to_date(self):
        self.assertEqual(self.run_update('pve', '--no-update', fail='same'), 0, self.output)
        self.assertIn('Everything is up to date', self.output)
        self.assertEqual(self.deploys(), [])

    def test_no_update_keeps_lock_and_pins(self):
        self.assertEqual(self.run_update('pve', '--no-update'), 0, self.output)
        self.assertFalse(any(c[:3] == ['nix', 'flake', 'update'] or c[0] == 'skopeo' for c in self.calls))
        self.assertIn(OLD, self.pin('gamma'))

    def test_no_images_keeps_pins(self):
        self.assertEqual(self.run_update('pve', '--no-images'), 0, self.output)
        self.assertTrue(any(c[:3] == ['nix', 'flake', 'update'] for c in self.calls))
        self.assertFalse(any(c[0] == 'skopeo' for c in self.calls))
        self.assertIn(OLD, self.pin('gamma'))

    def test_self_managed_images_are_left_alone(self):
        registry = json.loads((self.root / 'registry.json').read_text())
        beta = next(g for g in registry['guests'] if g['name'] == 'beta')
        beta['images'] = [{'container': 'app', 'image': f'example/app:latest@{OLD}'}]
        (self.root / 'registry.json').write_text(json.dumps(registry))
        self.run_update(reply='n\n')
        self.assertFalse(any(c[0] == 'skopeo' and 'example/app' in ' '.join(c) for c in self.calls))
        self.assertIn("updated by the app's own installer", self.output)

    def test_pin_found_twice_is_refused(self):
        with (self.repo / 'hosts/alpha.nix').open('a') as f:
            f.write(f'# lscr.io/linuxserver/player:latest@{OLD}\n')
        self.git('-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '-qam', 'duplicate')
        self.assertNotEqual(self.run_update(), 0)
        self.assertIn('appears 2 times', self.output)
        self.assertEqual(self.deploys(), [])

    def test_unchanged_digest_leaves_the_pin(self):
        self.assertEqual(self.run_update('gamma', digest=OLD), 0, self.output)
        self.assertIn(OLD, self.pin('gamma'))
        self.assertNotRegex(self.output, r'images\n +player')

    def stops_during(self, phase):
        self.assertNotEqual(self.run_update(fail=phase), 0)
        self.assertIn('during ' + phase, self.output)
        self.assertEqual(self.deploys(), [])

    def test_failed_checks_stop_before_deploy(self):
        self.stops_during('checks')

    def test_failed_build_stops_before_deploy(self):
        self.stops_during('build')

    def test_unknown_option(self):
        self.assertNotEqual(self.run_update('pve', '--cuda'), 0)
        self.assertIn("unknown option '--cuda'", self.output)
        self.assertEqual(self.calls, [])

    def test_untracked_files_are_refused(self):
        (self.repo / 'new.nix').write_text('{}')
        self.assertNotEqual(self.run_update(), 0)
        self.assertIn('untracked', self.output)
        self.assertEqual(self.calls, [])

    def test_concurrent_update(self):
        with (self.repo / '.git/cix-update.lock').open('w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.assertNotEqual(self.run_update(), 0)
        self.assertIn('Another cix update', self.output)
        self.assertEqual(self.calls, [])


if __name__ == '__main__':
    unittest.main()

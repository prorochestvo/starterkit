import contextlib
import hashlib
import io
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from datetime import date, timedelta
from unittest.mock import patch

import incubator


class IncubatorTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.env = patch.dict(os.environ, {'INCUBATOR_HOME': str(self.home)})
        self.env.start()
        self.addCleanup(self.env.stop)
        self.clock = patch.object(incubator, 'today', return_value=date(2026, 11, 21))
        self.clock.start()
        self.addCleanup(self.clock.stop)
        self.out = io.StringIO()
        self.err = io.StringIO()

    def cli(self, *args):
        with patch.object(sys, 'argv', ['incubator', *args]), \
                contextlib.redirect_stdout(self.out), contextlib.redirect_stderr(self.err):
            try:
                incubator.main()
                return 0
            except SystemExit as exc:
                return exc.code

    def observe(self, cid='trial-one', trigger='Use this when needed'):
        for index in range(3):
            result = self.cli('observe', '--id', cid, '--project', 'project', '--goal', 'goal',
                              '--trigger', trigger, '--evidence', f'evidence-{index}')
            self.assertEqual(result, 0, self.err.getvalue())
        self.out.seek(0)
        self.out.truncate()
        self.err.seek(0)
        self.err.truncate()

    def draft(self, cid='trial-one', content=b'procedure\n'):
        path = self.home / 'drafts' / f'{cid}.md'
        path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        path.write_bytes(content)
        return path

    def register(self, cid='trial-one', content=b'procedure\n', approved=None):
        path = self.draft(cid, content)
        args = ['candidate', '--id', cid]
        if approved is not None:
            args.extend(['--approved-sha256', approved])
        return self.cli(*args), path

    def read_registry(self):
        return json.loads((self.home / 'registry.json').read_text())

    def test_default_candidate_requires_owner_digest_and_registers(self):
        self.observe()
        content = b'procedure\n'
        self.draft(content=content)
        before = (self.home / 'registry.json').read_bytes()
        events = (self.home / 'events.jsonl').read_bytes()
        code = self.cli('candidate', '--id', 'trial-one')
        self.assertEqual(code, 1)
        self.assertIn(f'trial registration requires --approved-sha256; draft sha256: {hashlib.sha256(content).hexdigest()}',
                      self.err.getvalue())
        self.assertEqual((self.home / 'registry.json').read_bytes(), before)
        self.assertEqual((self.home / 'events.jsonl').read_bytes(), events)
        self.out.seek(0)
        self.out.truncate()
        self.err.seek(0)
        self.err.truncate()
        code, _ = self.register(approved=hashlib.sha256(content).hexdigest())
        self.assertEqual(code, 0, self.err.getvalue())
        entry = self.read_registry()['entries']['trial-one']
        self.assertEqual(entry['status'], 'trial')
        self.assertEqual(entry['approved_sha256'], hashlib.sha256(content).hexdigest())
        self.assertEqual(entry['review_at'], '2026-11-28')

    def test_wrong_digest_refuses_without_writes(self):
        self.observe()
        self.draft()
        before = (self.home / 'registry.json').read_bytes()
        events = (self.home / 'events.jsonl').read_bytes()
        self.assertEqual(self.cli('candidate', '--id', 'trial-one', '--approved-sha256', 'wrong'), 1)
        self.assertIn('draft does not match the approved sha256', self.err.getvalue())
        self.assertEqual((self.home / 'registry.json').read_bytes(), before)
        self.assertEqual((self.home / 'events.jsonl').read_bytes(), events)

    def test_source_confinement_and_size(self):
        self.observe()
        outside = self.home / 'outside.md'
        outside.write_text('outside')
        drafts = self.home / 'drafts'
        drafts.mkdir(mode=0o755)
        symlink = drafts / 'trial-one.md'
        symlink.symlink_to(outside)
        before = (self.home / 'registry.json').read_bytes()
        events = (self.home / 'events.jsonl').read_bytes()
        for args in (['--from', '/etc/hosts'], [], ['--from', str(drafts / 'trial-one.md')],
                     ['--from', str(drafts / '..' / 'registry.json')]):
            self.out.seek(0)
            self.out.truncate()
            self.err.seek(0)
            self.err.truncate()
            command = ['candidate', '--id', 'trial-one', *args, '--approved-sha256', 'irrelevant']
            self.assertEqual(self.cli(*command), 1)
            self.assertIn(f'procedure must be a regular file under {drafts}', self.err.getvalue())
            self.assertEqual((self.home / 'registry.json').read_bytes(), before)
            self.assertEqual((self.home / 'events.jsonl').read_bytes(), events)
        symlink.unlink()
        hardlink = drafts / 'trial-one.md'
        os.link(outside, hardlink)
        self.out.seek(0)
        self.out.truncate()
        self.err.seek(0)
        self.err.truncate()
        self.assertEqual(self.cli('candidate', '--id', 'trial-one', '--approved-sha256', 'irrelevant'), 1)
        self.assertIn(f'procedure must be a regular file under {drafts}', self.err.getvalue())
        hardlink.unlink()
        large = b'x' * (65 * 1024)
        self.draft(content=large)
        self.out.seek(0)
        self.out.truncate()
        self.err.seek(0)
        self.err.truncate()
        self.assertEqual(self.cli('candidate', '--id', 'trial-one', '--approved-sha256', hashlib.sha256(large).hexdigest()), 1)
        self.assertIn('procedure larger than 64 KiB', self.err.getvalue())

    def test_draft_of_exactly_64_kib_is_accepted(self):
        self.observe()
        content = b'x' * (64 * 1024)
        code, _ = self.register(content=content, approved=hashlib.sha256(content).hexdigest())
        self.assertEqual(code, 0, self.err.getvalue())

    def test_unchanged_approval_keeps_dates_and_new_version_restarts_trial(self):
        self.observe()
        first = b'procedure\n'
        self.assertEqual(self.register(content=first, approved=hashlib.sha256(first).hexdigest())[0], 0)
        events = (self.home / 'events.jsonl').read_bytes()
        later = date(2026, 12, 1)
        with patch.object(incubator, 'today', return_value=later):
            self.out.seek(0)
            self.out.truncate()
            self.assertEqual(self.register(content=first, approved=hashlib.sha256(first).hexdigest())[0], 0)
            self.assertTrue(json.loads(self.out.getvalue())['unchanged'])
            entry = self.read_registry()['entries']['trial-one']
            self.assertEqual(entry['trial_started_at'], '2026-11-21')
            self.assertEqual(entry['review_at'], '2026-11-28')
            self.assertEqual((self.home / 'events.jsonl').read_bytes(), events)
            second = b'procedure v2\n'
            self.assertEqual(self.register(content=second, approved=hashlib.sha256(second).hexdigest())[0], 0)
            entry = self.read_registry()['entries']['trial-one']
            self.assertEqual(entry['trial_started_at'], '2026-12-01')
            self.assertEqual(entry['review_at'], '2026-12-08')
        data = self.read_registry()
        data['entries']['trial-one'].pop('approved_sha256')
        (self.home / 'registry.json').write_text(json.dumps(data))
        legacy = date(2026, 12, 5)
        with patch.object(incubator, 'today', return_value=legacy):
            self.assertEqual(self.register(content=second, approved=hashlib.sha256(second).hexdigest())[0], 0)
        entry = self.read_registry()['entries']['trial-one']
        self.assertEqual(entry['trial_started_at'], '2026-12-05')
        self.assertEqual(entry['review_at'], '2026-12-12')

    def test_malformed_entry_and_non_utf8_registry_are_unsupported(self):
        for raw in (json.dumps({'version': 1, 'entries': {'x': {}}}).encode(), b'\xff'):
            (self.home / 'registry.json').write_bytes(raw)
            self.err.seek(0)
            self.err.truncate()
            self.assertEqual(self.cli('list'), 1)
            self.assertIn('unsupported registry format', self.err.getvalue())

    def test_draft_path_creates_directory_and_prints_absolute_path(self):
        self.assertEqual(self.cli('draft-path', '--id', 'trial-one'), 0)
        self.assertEqual(self.out.getvalue().strip(), str((self.home / 'drafts' / 'trial-one.md').resolve()))
        self.assertTrue((self.home / 'drafts').is_dir())

    def test_run_and_record_require_approved_bytes(self):
        self.observe()
        content = b'approved procedure\n'
        self.register(content=content, approved=hashlib.sha256(content).hexdigest())
        self.assertEqual(self.cli('run', '--id', 'trial-one'), 0)
        self.assertIn('approved procedure', self.out.getvalue())
        self.draft(content=b'edited procedure\n')
        self.assertEqual(self.cli('candidate', '--id', 'trial-one', '--approved-sha256',
                                  hashlib.sha256(b'edited procedure\n').hexdigest()), 0)
        procedure = self.home / 'candidates' / 'trial-one' / 'procedure.md'
        procedure.write_bytes(b'edited again\n')
        self.out.seek(0)
        self.out.truncate()
        self.err.seek(0)
        self.err.truncate()
        self.assertEqual(self.cli('run', '--id', 'trial-one'), 1)
        self.assertIn('procedure differs from the approved version; re-approve with candidate --approved-sha256',
                      self.err.getvalue())
        self.err.seek(0)
        self.err.truncate()
        self.assertEqual(self.cli('record', '--id', 'trial-one', '--use-id', 'use-1', '--project', 'project'), 1)
        self.assertIn('procedure differs from the approved version; re-approve with candidate --approved-sha256',
                      self.err.getvalue())

    def test_legacy_trial_remains_listable_reviewable_and_closable(self):
        self.observe()
        code, _ = self.register(approved=hashlib.sha256(b'procedure\n').hexdigest())
        self.assertEqual(code, 0)
        data = self.read_registry()
        data['entries']['trial-one'].pop('approved_sha256')
        (self.home / 'registry.json').write_text(json.dumps(data))
        self.err.seek(0)
        self.err.truncate()
        self.assertEqual(self.cli('run', '--id', 'trial-one'), 1)
        self.assertIn('procedure differs from the approved version', self.err.getvalue())
        self.assertEqual(self.cli('list'), 0)
        self.assertEqual(self.cli('review', '--all'), 0)
        self.assertEqual(self.cli('close', '--id', 'trial-one', '--status', 'archived'), 0)

    def test_triggers_filters_sanitizes_and_truncates(self):
        self.observe('alpha', 'line\nbreak')
        content = b'p1'
        self.register('alpha', content, hashlib.sha256(content).hexdigest())
        self.observe('beta', 'z' * 400)
        content = b'p2'
        self.register('beta', content, hashlib.sha256(content).hexdigest())
        self.observe('legacy')
        self.register('legacy', b'p3', hashlib.sha256(b'p3').hexdigest())
        data = self.read_registry()
        data['entries']['legacy'].pop('approved_sha256')
        (self.home / 'registry.json').write_text(json.dumps(data))
        self.observe('closed')
        content = b'p4'
        self.register('closed', content, hashlib.sha256(content).hexdigest())
        self.assertEqual(self.cli('close', '--id', 'closed', '--status', 'archived'), 0)
        self.observe('observed')
        self.out.seek(0)
        self.out.truncate()
        self.out.seek(0)
        self.out.truncate()
        self.assertEqual(self.cli('triggers'), 0)
        lines = self.out.getvalue().splitlines()
        self.assertEqual(lines[0], incubator.TRIGGERS_HEADER)
        self.assertEqual(lines[1], 'alpha: line break')
        self.assertEqual(lines[2], 'beta: ' + 'z' * 300 + '…')
        self.assertEqual(len(lines), 3)

    def test_drafts_symlink_is_rejected(self):
        self.observe()
        outside = self.home / 'outside'
        outside.mkdir()
        (outside / 'trial-one.md').write_text('procedure')
        (self.home / 'drafts').symlink_to(outside, target_is_directory=True)
        self.assertEqual(self.cli('candidate', '--id', 'trial-one', '--approved-sha256',
                                  hashlib.sha256(b'procedure').hexdigest()), 1)
        self.assertIn('drafts must be a real directory', self.err.getvalue())

    def test_triggers_missing_state_and_corrupt_registry(self):
        self.home = self.home / 'state'
        os.environ['INCUBATOR_HOME'] = str(self.home)
        self.assertEqual(self.cli('triggers'), 0)
        self.assertEqual(self.out.getvalue(), '')
        self.assertFalse(self.home.exists())
        (self.home / 'registry.json').parent.mkdir(parents=True)
        (self.home / 'registry.json').write_text('{"version":1,"entries":{}}')
        self.out.seek(0)
        self.out.truncate()
        self.assertEqual(self.cli('triggers'), 0)
        self.assertEqual(self.out.getvalue(), '')
        for raw in ('{', '[]', 'null', '42'):
            (self.home / 'registry.json').write_text(raw)
            self.out.seek(0)
            self.out.truncate()
            self.err.seek(0)
            self.err.truncate()
            self.assertEqual(self.cli('triggers'), 0)
            self.assertEqual(len(self.err.getvalue().splitlines()), 1)
            self.err.seek(0)
            self.err.truncate()
            self.assertEqual(self.cli('list'), 1)
            self.assertIn('unsupported registry format', self.err.getvalue())

    def test_registry_rejects_non_object_entries(self):
        self.home.mkdir(parents=True, exist_ok=True)
        (self.home / 'registry.json').write_text('{"version":1,"entries":{"bad":[]}}')
        self.assertEqual(self.cli('list'), 1)
        self.assertIn('unsupported registry format', self.err.getvalue())

    def test_trial_start_date_and_extend_review_timing(self):
        self.observe()
        content = b'procedure\n'
        self.register(content=content, approved=hashlib.sha256(content).hexdigest())
        entry = self.read_registry()['entries']['trial-one']
        self.assertEqual(entry['trial_started_at'], '2026-11-21')
        self.out.seek(0)
        self.out.truncate()
        self.assertEqual(self.cli('extend', '--id', 'trial-one', '--reason', 'decision review'), 0)
        entry = self.read_registry()['entries']['trial-one']
        self.assertEqual(entry['review_at'], '2026-12-21')
        self.assertEqual(entry['extensions'][0]['review_at'], '2026-12-21')
        events = [json.loads(line) for line in (self.home / 'events.jsonl').read_text().splitlines()]
        self.assertEqual(events[-1]['type'], 'extend')
        self.out.seek(0)
        self.out.truncate()
        self.assertEqual(self.cli('review'), 0)
        self.assertEqual(json.loads(self.out.getvalue()), [])

    def test_extend_uses_today_for_old_trials_and_days_override(self):
        self.observe()
        content = b'procedure\n'
        self.register(content=content, approved=hashlib.sha256(content).hexdigest())
        data = self.read_registry()
        data['entries']['trial-one']['trial_started_at'] = (date(2026, 11, 21) - timedelta(days=40)).isoformat()
        (self.home / 'registry.json').write_text(json.dumps(data))
        self.assertEqual(self.cli('extend', '--id', 'trial-one', '--reason', 'continue'), 0)
        self.assertEqual(self.read_registry()['entries']['trial-one']['review_at'], '2026-12-21')
        self.out.seek(0)
        self.out.truncate()
        self.assertEqual(self.cli('extend', '--id', 'trial-one', '--reason', 'short check', '--days', '5'), 0)
        self.assertEqual(self.read_registry()['entries']['trial-one']['review_at'], '2026-11-26')

    def test_extend_refusals_do_not_write(self):
        self.observe()
        content = b'procedure\n'
        self.register(content=content, approved=hashlib.sha256(content).hexdigest())
        before = (self.home / 'registry.json').read_bytes()
        events = (self.home / 'events.jsonl').read_bytes()
        for args in ([], ['--reason', 'bad', '--days', '0']):
            self.out.seek(0)
            self.out.truncate()
            self.err.seek(0)
            self.err.truncate()
            self.assertEqual(self.cli('extend', '--id', 'trial-one', *args), 1)
            self.assertEqual((self.home / 'registry.json').read_bytes(), before)
            self.assertEqual((self.home / 'events.jsonl').read_bytes(), events)
        self.out.seek(0)
        self.out.truncate()
        self.err.seek(0)
        self.err.truncate()
        self.assertEqual(self.cli('observe', '--id', 'observed', '--project', 'p', '--goal', 'g',
                                  '--trigger', 't', '--evidence', 'e1'), 0)
        before = (self.home / 'registry.json').read_bytes()
        events = (self.home / 'events.jsonl').read_bytes()
        self.out.seek(0)
        self.out.truncate()
        self.err.seek(0)
        self.err.truncate()
        self.assertEqual(self.cli('extend', '--id', 'observed', '--reason', 'bad'), 1)
        self.assertEqual((self.home / 'registry.json').read_bytes(), before)
        self.assertEqual((self.home / 'events.jsonl').read_bytes(), events)

    def test_review_age_stage_and_legacy_created_date(self):
        self.observe('modern')
        self.observe('legacy')
        content = b'procedure\n'
        for cid in ('modern', 'legacy'):
            self.register(cid, content, hashlib.sha256(content).hexdigest())
        data = self.read_registry()
        data['entries']['modern']['trial_started_at'] = '2026-10-22'
        data['entries']['legacy'].pop('trial_started_at')
        data['entries']['legacy']['created_at'] = '2026-10-23T12:00:00Z'
        (self.home / 'registry.json').write_text(json.dumps(data))
        self.out.seek(0)
        self.out.truncate()
        self.assertEqual(self.cli('review', '--all'), 0)
        entries = json.loads(self.out.getvalue())
        self.assertEqual([(e['age_days'], e['stage']) for e in entries],
                         [(29, 'first'), (30, 'decision')])

    def test_observe_reuses_existing_wording_and_rejects_changes(self):
        self.observe('repeat')
        self.out.seek(0)
        self.out.truncate()
        self.assertEqual(self.cli('observe', '--id', 'repeat', '--project', 'p', '--evidence', 'e4'), 0)
        self.assertEqual(len(self.read_registry()['entries']['repeat']['occurrences']), 4)
        self.out.seek(0)
        self.out.truncate()
        self.err.seek(0)
        self.err.truncate()
        self.assertEqual(self.cli('observe', '--id', 'repeat', '--project', 'p', '--goal', 'different',
                                  '--evidence', 'e5'), 1)
        self.assertIn('goal', self.err.getvalue())
        self.assertIn('Use this when needed', self.err.getvalue())
        self.out.seek(0)
        self.out.truncate()
        self.err.seek(0)
        self.err.truncate()
        self.assertEqual(self.cli('observe', '--id', 'new', '--project', 'p', '--evidence', 'e'), 1)
        self.assertIn('goal and trigger required for a new pattern', self.err.getvalue())

    def test_observed_can_be_archived_but_not_promoted(self):
        self.observe('archive-me')
        self.assertEqual(self.cli('close', '--id', 'archive-me', '--status', 'archived'), 0)
        self.assertEqual(self.read_registry()['entries']['archive-me']['status'], 'archived')
        self.assertEqual(json.loads((self.home / 'events.jsonl').read_text().splitlines()[-1])['type'], 'close')
        self.out.seek(0)
        self.out.truncate()
        self.err.seek(0)
        self.err.truncate()
        self.assertEqual(self.cli('observe', '--id', 'archive-me', '--project', 'p', '--evidence', 'e4'), 1)
        self.assertIn('pattern is closed', self.err.getvalue())
        self.observe('promotion-me')
        target = self.home / 'target.md'
        target.write_text('target')
        self.out.seek(0)
        self.out.truncate()
        self.err.seek(0)
        self.err.truncate()
        self.assertEqual(self.cli('close', '--id', 'promotion-me', '--status', 'promoted', '--approved',
                                  '--target', str(target)), 1)
        self.assertIn('not in trial', self.err.getvalue())

    def test_compact_list_all_and_show(self):
        self.observe('open-one')
        self.observe('open-two')
        self.observe('closed-one')
        self.assertEqual(self.cli('close', '--id', 'closed-one', '--status', 'archived'), 0)
        self.out.seek(0)
        self.out.truncate()
        self.assertEqual(self.cli('list'), 0)
        entries = json.loads(self.out.getvalue())
        self.assertEqual(len(entries), 2)
        self.assertEqual(entries[0]['observations'], 3)
        self.assertEqual(entries[0]['uses'], 0)
        self.assertNotIn('occurrences', entries[0])
        self.assertNotIsInstance(entries[0]['uses'], list)
        self.out.seek(0)
        self.out.truncate()
        self.assertEqual(self.cli('list', '--all'), 0)
        self.assertEqual(len(json.loads(self.out.getvalue())), 3)
        self.out.seek(0)
        self.out.truncate()
        self.assertEqual(self.cli('show', '--id', 'open-one'), 0)
        self.assertEqual(json.loads(self.out.getvalue()), self.read_registry()['entries']['open-one'])
        self.out.seek(0)
        self.out.truncate()
        self.err.seek(0)
        self.err.truncate()
        self.assertEqual(self.cli('show', '--id', 'unknown'), 1)
        self.assertIn('unknown pattern: unknown', self.err.getvalue())


if __name__ == '__main__':
    unittest.main()

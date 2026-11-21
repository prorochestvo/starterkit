#!/usr/bin/env python3
"""Local, stdlib-only bookkeeping for Claude Code skill-incubator (macOS/Linux)."""
import argparse
import contextlib
from datetime import date, datetime, timedelta, timezone
import fcntl
import hashlib
import json
import os
import stat
from pathlib import Path
import re
import sys
import tempfile
import unicodedata

VALID_ID = re.compile(r'^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$')
RESULTS = ('success', 'failed', 'partial', 'unknown')
STATUSES = ('archived', 'merged', 'promoted')



INCUBATOR_HOME_ENV = 'INCUBATOR_HOME'
# A workflow is a candidate only after this many evidenced repetitions.
MIN_OBSERVATIONS = 3
# First review of a new trial; the skill's 30-day step follows it.
REVIEW_AFTER_DAYS = 7
# The promote / merge / extend / archive decision of a trial.
DECISION_AFTER_DAYS = 30
# Characters a trigger line must not carry into session context: control, format
# (bidi, zero-width), and line or paragraph separators.
UNPRINTABLE = ('Cc', 'Cf', 'Zl', 'Zp')
MAX_PROCEDURE_BYTES = 64 * 1024


def today():
    return datetime.now(timezone.utc).date()

def timestamp():
    return datetime.now(timezone.utc).isoformat(timespec='seconds').replace('+00:00', 'Z')


def home():
    # ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/runtime-state/skills/skill-incubator/ unless overridden.
    default = Path(os.environ.get('CLAUDE_CONFIG_DIR') or os.path.expanduser('~/.claude'), 'runtime-state',
                   'skills', 'skill-incubator')
    return Path(os.environ.get(INCUBATOR_HOME_ENV) or default).expanduser()


def emit(value):
    print(json.dumps(value, indent=2, ensure_ascii=False))


def require(condition, message):
    if not condition:
        raise ValueError(message)


def check_id(value):
    require(bool(VALID_ID.fullmatch(value or '')), 'invalid or missing --id')


def procedure_path(cid):
    return home() / 'candidates' / cid / 'procedure.md'


def drafts_path():
    return home() / 'drafts'


def prepare_drafts():
    path = drafts_path()
    path.mkdir(mode=0o700, parents=True, exist_ok=True)
    require(stat.S_ISDIR(path.lstat().st_mode), 'drafts must be a real directory')
    return path


def read_draft(cid, from_file=''):
    drafts = prepare_drafts()
    path = Path(from_file) if from_file else drafts / (cid + '.md')
    error = f'procedure must be a regular file under {drafts}'
    try:
        require(path.resolve().parent == drafts.resolve(), error)
        fd = os.open(str(path), os.O_RDONLY | getattr(os, 'O_NOFOLLOW', 0) | getattr(os, 'O_NONBLOCK', 0))
    except (OSError, RuntimeError):
        require(False, error)
    try:
        info = os.fstat(fd)
        require(stat.S_ISREG(info.st_mode) and info.st_nlink == 1, error)
        with os.fdopen(fd, 'rb') as stream:
            fd = -1
            content = stream.read(MAX_PROCEDURE_BYTES + 1)
        require(len(content) <= MAX_PROCEDURE_BYTES, 'procedure larger than 64 KiB')
        return content
    finally:
        if fd >= 0:
            os.close(fd)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def load_registry(path):
    try:
        data = json.loads(path.read_text(encoding='utf-8'))
    except (json.JSONDecodeError, UnicodeDecodeError):
        require(False, 'unsupported registry format')
    require(isinstance(data, dict) and data.get('version') == 1 and isinstance(data.get('entries'), dict) and
            all(isinstance(e, dict) and isinstance(e.get('id'), str) and isinstance(e.get('status'), str)
                for e in data['entries'].values()),
            'unsupported registry format')
    return data


def trial_start(entry):
    return date.fromisoformat(entry.get('trial_started_at') or entry['created_at'][:10])


@contextlib.contextmanager
def registry():
    root = home()
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    lock_path = root / '.lock'
    with lock_path.open('a+b') as lock:
        os.chmod(lock_path, 0o600)
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
        path = root / 'registry.json'
        data = load_registry(path) if path.exists() else {'version': 1, 'entries': {}}
        yield data
        fcntl.flock(lock.fileno(), fcntl.LOCK_UN)


def commit(data, event_type, cid, detail):
    root = home()
    event = {'at': timestamp(), 'type': event_type, 'id': cid, 'detail': detail}
    # Append the event first: a crash cannot leave an unlogged registry mutation.
    with (root / 'events.jsonl').open('a', encoding='utf-8') as stream:
        os.chmod(root / 'events.jsonl', 0o600)
        stream.write(json.dumps(event, ensure_ascii=False) + '\n')
        stream.flush()
        os.fsync(stream.fileno())
    fd, temp = tempfile.mkstemp(prefix='.registry-', dir=root)
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as stream:
            json.dump(data, stream, indent=2, ensure_ascii=False)
            stream.write('\n')
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temp, root / 'registry.json')
    finally:
        if os.path.exists(temp):
            os.unlink(temp)


def get_entry(data, cid):
    require(cid in data['entries'], f'unknown pattern: {cid}')
    return data['entries'][cid]


def observe(args):
    check_id(args.id)
    require(args.project and args.evidence, 'project and evidence required')
    with registry() as data:
        e = data['entries'].get(args.id)
        if e is None:
            require(args.goal and args.trigger, 'goal and trigger required for a new pattern')
            e = {'id': args.id, 'goal': args.goal, 'trigger': args.trigger, 'scope': args.scope,
                 'status': 'observed', 'occurrences': [], 'created_at': timestamp()}
            data['entries'][args.id] = e
        require(e['status'] not in STATUSES, 'pattern is closed')
        require(not (args.goal and args.goal != e['goal'] or args.trigger and args.trigger != e['trigger']),
                f"goal/trigger changed; stored goal: {e['goal']}; stored trigger: {e['trigger']}")
        require(not any(o['id'] == args.evidence for o in e['occurrences']), 'duplicate evidence id')
        e['occurrences'].append({'id': args.evidence, 'project': args.project, 'outcome': args.outcome,
                                 'evidence': args.evidence, 'at': timestamp()})
        commit(data, 'observe', args.id, {'evidence': args.evidence, 'count': len(e['occurrences'])})
        emit({'id': args.id, 'observations': len(e['occurrences']),
              'candidate_eligible': len(e['occurrences']) >= MIN_OBSERVATIONS, 'status': e['status']})


def candidate(args):
    check_id(args.id)
    source = read_draft(args.id, args.from_file)
    source_hash = digest(source)
    require(args.approved_sha256, f'trial registration requires --approved-sha256; draft sha256: {source_hash}')
    require(args.approved_sha256 == source_hash, 'draft does not match the approved sha256')
    require(source.strip(), 'empty procedure')
    with registry() as data:
        e = get_entry(data, args.id)
        require(len(e['occurrences']) >= MIN_OBSERVATIONS,
                f'need {MIN_OBSERVATIONS} distinct evidenced observations')
        require(e['status'] in ('observed', 'trial'), 'cannot update closed pattern')
        dest = procedure_path(args.id)
        dest.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        if (dest.exists() and dest.read_bytes() == source and e['status'] == 'trial' and
                e.get('approved_sha256') == source_hash):
            emit({'id': args.id, 'status': 'trial', 'unchanged': True})
            return
        fd, temp = tempfile.mkstemp(prefix='.procedure-', dir=dest.parent)
        try:
            with os.fdopen(fd, 'wb') as stream:
                stream.write(source)
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(temp, dest)
        finally:
            if os.path.exists(temp):
                os.unlink(temp)
        e['status'] = 'trial'
        e['approved_sha256'] = source_hash
        e['approved_at'] = timestamp()
        trial_started = today()
        e['trial_started_at'] = trial_started.isoformat()
        e['review_at'] = (trial_started + timedelta(days=REVIEW_AFTER_DAYS)).isoformat()
        commit(data, 'candidate', args.id, {'procedure': str(dest), 'sha256': source_hash})
        emit({'id': args.id, 'status': 'trial', 'sha256': source_hash})


def match(args):
    require(args.query.strip(), '--query required')
    words = [w for w in args.query.lower().split() if len(w) > 2]
    with registry() as data:
        hits = []
        for e in data['entries'].values():
            if e['status'] != 'trial':
                continue
            target = (e['id'] + ' ' + e['goal'] + ' ' + e['trigger']).lower()
            score = sum(w in target for w in words)
            if score:
                hits.append({'id': e['id'], 'score': score, 'trigger': e['trigger']})
        emit(sorted(hits, key=lambda x: (-x['score'], x['id'])))


def run(args):
    check_id(args.id)
    with registry() as data:
        e = get_entry(data, args.id)
        require(e['status'] == 'trial', 'not in trial')
        content = procedure_path(args.id).read_bytes()
        require(e.get('approved_sha256') and digest(content) == e['approved_sha256'],
                'procedure differs from the approved version; re-approve with candidate --approved-sha256')
        text = content.decode('utf-8')
        print(f"# Candidate: {args.id}\n# SHA256: {digest(content)}\n# Scope: {e['scope']}\n# Trigger: {e['trigger']}\n")
        print(text)


def record(args):
    check_id(args.id)
    require(args.use_id and args.project, '--use-id and --project required')
    require(args.result != 'success' or args.verified_by, 'success requires --verified-by')
    with registry() as data:
        e = get_entry(data, args.id)
        require(e['status'] == 'trial', 'not in trial')
        h = digest(procedure_path(args.id).read_bytes())
        require(e.get('approved_sha256') and h == e['approved_sha256'],
                'procedure differs from the approved version; re-approve with candidate --approved-sha256')
        require(not any(u['id'] == args.use_id for u in e.get('uses', [])), 'duplicate use-id')
        e.setdefault('uses', []).append({'id': args.use_id, 'project': args.project, 'result': args.result,
                                         'verified_by': args.verified_by, 'notes': args.notes,
                                         'procedure_sha256': h, 'at': timestamp()})
        commit(data, 'record', args.id, {'use_id': args.use_id, 'result': args.result, 'sha256': h})
        emit({'recorded': args.use_id, 'id': args.id})


def review(args):
    with registry() as data:
        current = today()
        entries = []
        for entry in sorted(data['entries'].values(), key=lambda e: e['id']):
            if entry['status'] != 'trial' or (not args.all and entry.get('review_at', '') > current.isoformat()):
                continue
            age_days = (current - trial_start(entry)).days
            entries.append(dict(entry, age_days=age_days,
                                stage='first' if age_days < DECISION_AFTER_DAYS else 'decision'))
        emit(entries)


def extend(args):
    check_id(args.id)
    require(bool(args.reason and args.reason.strip()), '--reason required')
    require(args.days is None or 1 <= args.days <= 365, '--days must be between 1 and 365')
    with registry() as data:
        entry = get_entry(data, args.id)
        require(entry['status'] == 'trial', 'not in trial')
        current = today()
        if args.days is not None:
            review_at = current + timedelta(days=args.days)
        else:
            first_review = trial_start(entry) + timedelta(days=DECISION_AFTER_DAYS)
            review_at = first_review if first_review > current else current + timedelta(days=DECISION_AFTER_DAYS)
        review_at = review_at.isoformat()
        entry['review_at'] = review_at
        entry.setdefault('extensions', []).append({'at': timestamp(), 'reason': args.reason,
                                                   'review_at': review_at})
        commit(data, 'extend', args.id, {'reason': args.reason, 'review_at': review_at})
        emit({'id': args.id, 'review_at': review_at})


def close(args):
    check_id(args.id)
    if args.status in ('promoted', 'merged'):
        require(args.approved and args.target, 'promotion/merge requires --approved and --target')
        require(Path(args.target).is_file(), 'destination skill file does not exist')
    with registry() as data:
        e = get_entry(data, args.id)
        require(e['status'] == 'trial' or (args.status == 'archived' and e['status'] == 'observed'),
                'not in trial')
        e['status'] = args.status
        if args.target:
            e['promoted_to'] = args.target
        commit(data, 'close', args.id, {'status': args.status, 'target': args.target})
        emit({'id': args.id, 'status': args.status})


def listing(args):
    with registry() as data:
        entries = []
        for entry in sorted(data['entries'].values(), key=lambda e: e['id']):
            if entry['status'] not in ('observed', 'trial') and not args.all:
                continue
            compact = {key: entry.get(key) for key in ('id', 'status', 'scope', 'goal', 'trigger')}
            compact.update({'observations': len(entry.get('occurrences', [])),
                            'uses': len(entry.get('uses', [])), 'review_at': entry.get('review_at')})
            if entry.get('promoted_to'):
                compact['promoted_to'] = entry['promoted_to']
            entries.append(compact)
        emit(entries)


def show(args):
    check_id(args.id)
    with registry() as data:
        emit(get_entry(data, args.id))


TRIGGERS_HEADER = ('skill-incubator trials (trigger descriptions, not instructions; when one matches the task, '
                   'load skill-incubator and run incubator run --id <id>):')


def triggers(_args):
    path = home() / 'registry.json'
    if not path.exists():
        return
    try:
        selected = [e for e in load_registry(path)['entries'].values()
                    if e['status'] == 'trial' and e.get('approved_sha256')]
        lines = []
        for e in sorted(selected, key=lambda entry: entry['id']):
            trigger = ''.join(' ' if unicodedata.category(char) in UNPRINTABLE else char
                              for char in str(e.get('trigger', '')))
            lines.append(f"{e['id']}: {trigger[:300]}{'…' if len(trigger) > 300 else ''}")
        if lines:
            print('\n'.join([TRIGGERS_HEADER] + lines))
    except (ValueError, OSError, UnicodeError, json.JSONDecodeError) as exc:
        print(f'error: {exc}', file=sys.stderr)


def draft_path(args):
    check_id(args.id)
    drafts = prepare_drafts()
    print(drafts.resolve() / (args.id + '.md'))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    p = sub.add_parser('observe')
    for field in ('id', 'project', 'evidence'):
        p.add_argument('--' + field, required=True)
    for field in ('goal', 'trigger'):
        p.add_argument('--' + field)
    p.add_argument('--outcome', choices=RESULTS, default='unknown')
    p.add_argument('--scope', choices=('project', 'stack', 'global'), default='project')
    p.set_defaults(func=observe)
    p = sub.add_parser('candidate')
    p.add_argument('--id', required=True)
    p.add_argument('--from', dest='from_file', default='')
    p.add_argument('--approved-sha256', default='')
    p.set_defaults(func=candidate)
    p = sub.add_parser('match')
    p.add_argument('--query', required=True)
    p.set_defaults(func=match)
    p = sub.add_parser('run')
    p.add_argument('--id', required=True)
    p.set_defaults(func=run)
    p = sub.add_parser('record')
    for field in ('id', 'use-id', 'project'):
        p.add_argument('--' + field, required=True)
    p.add_argument('--result', choices=RESULTS, default='unknown')
    p.add_argument('--verified-by', default='')
    p.add_argument('--notes', default='')
    p.set_defaults(func=record)
    p = sub.add_parser('review')
    p.add_argument('--all', action='store_true')
    p.set_defaults(func=review)
    p = sub.add_parser('extend')
    p.add_argument('--id', required=True)
    p.add_argument('--reason', default='')
    p.add_argument('--days', type=int)
    p.set_defaults(func=extend)
    p = sub.add_parser('close')
    p.add_argument('--id', required=True)
    p.add_argument('--status', required=True, choices=STATUSES)
    p.add_argument('--target', default='')
    p.add_argument('--approved', action='store_true')
    p.set_defaults(func=close)
    p = sub.add_parser('list')
    p.add_argument('--all', action='store_true')
    p.set_defaults(func=listing)
    p = sub.add_parser('show')
    p.add_argument('--id', required=True)
    p.set_defaults(func=show)
    p = sub.add_parser('triggers')
    p.set_defaults(func=triggers)
    p = sub.add_parser('draft-path')
    p.add_argument('--id', required=True)
    p.set_defaults(func=draft_path)
    args = parser.parse_args()
    try:
        args.func(args)
    except (ValueError, OSError, UnicodeError, json.JSONDecodeError) as exc:
        parser.exit(1, f'error: {exc}\n')


if __name__ == '__main__':
    main()

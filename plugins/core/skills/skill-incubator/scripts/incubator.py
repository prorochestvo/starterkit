#!/usr/bin/env python3
"""Local, stdlib-only bookkeeping for Claude Code skill-incubator (macOS/Linux)."""
import argparse
import contextlib
from datetime import datetime, timedelta, timezone
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import tempfile

VALID_ID = re.compile(r'^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$')
RESULTS = ('success', 'failed', 'partial', 'unknown')
STATUSES = ('archived', 'merged', 'promoted')



INCUBATOR_HOME_ENV = 'INCUBATOR_HOME'
# A workflow is a candidate only after this many evidenced repetitions.
MIN_OBSERVATIONS = 3
# First review of a new trial; the skill's 30-day step follows it.
REVIEW_AFTER_DAYS = 7

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


def digest(data):
    return hashlib.sha256(data).hexdigest()


@contextlib.contextmanager
def registry():
    root = home()
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    lock_path = root / '.lock'
    with lock_path.open('a+b') as lock:
        os.chmod(lock_path, 0o600)
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
        path = root / 'registry.json'
        data = json.loads(path.read_text(encoding='utf-8')) if path.exists() else {'version': 1, 'entries': {}}
        require(data.get('version') == 1 and isinstance(data.get('entries'), dict), 'unsupported registry format')
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
    require(all([args.project, args.goal, args.trigger, args.evidence]), 'project, goal, trigger and evidence required')
    with registry() as data:
        e = data['entries'].get(args.id)
        if e is None:
            e = {'id': args.id, 'goal': args.goal, 'trigger': args.trigger, 'scope': args.scope,
                 'status': 'observed', 'occurrences': [], 'created_at': timestamp()}
            data['entries'][args.id] = e
        require(e['status'] not in STATUSES, 'pattern is closed')
        require(e['goal'] == args.goal and e['trigger'] == args.trigger,
                'goal/trigger changed; verify semantics before merging observations')
        require(not any(o['id'] == args.evidence for o in e['occurrences']), 'duplicate evidence id')
        e['occurrences'].append({'id': args.evidence, 'project': args.project, 'outcome': args.outcome,
                                 'evidence': args.evidence, 'at': timestamp()})
        commit(data, 'observe', args.id, {'evidence': args.evidence, 'count': len(e['occurrences'])})
        emit({'id': args.id, 'observations': len(e['occurrences']),
              'candidate_eligible': len(e['occurrences']) >= MIN_OBSERVATIONS, 'status': e['status']})


def candidate(args):
    check_id(args.id)
    source = Path(args.from_file).read_bytes()
    require(source.strip(), 'empty procedure')
    with registry() as data:
        e = get_entry(data, args.id)
        require(len(e['occurrences']) >= MIN_OBSERVATIONS,
                f'need {MIN_OBSERVATIONS} distinct evidenced observations')
        require(e['status'] in ('observed', 'candidate', 'trial'), 'cannot update closed pattern')
        dest = procedure_path(args.id)
        dest.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        if dest.exists() and dest.read_bytes() == source and e['status'] == 'trial':
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
        e['review_at'] = (datetime.now(timezone.utc) + timedelta(days=REVIEW_AFTER_DAYS)).date().isoformat()
        commit(data, 'candidate', args.id, {'procedure': str(dest), 'sha256': digest(source)})
        emit({'id': args.id, 'status': 'trial', 'sha256': digest(source)})


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
        print(f"# Candidate: {args.id}\n# SHA256: {digest(content)}\n# Scope: {e['scope']}\n# Trigger: {e['trigger']}\n")
        print(content.decode('utf-8'))


def record(args):
    check_id(args.id)
    require(args.use_id and args.project, '--use-id and --project required')
    require(args.result != 'success' or args.verified_by, 'success requires --verified-by')
    with registry() as data:
        e = get_entry(data, args.id)
        require(e['status'] == 'trial', 'not in trial')
        require(not any(u['id'] == args.use_id for u in e.get('uses', [])), 'duplicate use-id')
        h = digest(procedure_path(args.id).read_bytes())
        e.setdefault('uses', []).append({'id': args.use_id, 'project': args.project, 'result': args.result,
                                         'verified_by': args.verified_by, 'notes': args.notes,
                                         'procedure_sha256': h, 'at': timestamp()})
        commit(data, 'record', args.id, {'use_id': args.use_id, 'result': args.result, 'sha256': h})
        emit({'recorded': args.use_id, 'id': args.id})


def review(args):
    with registry() as data:
        today = datetime.now(timezone.utc).date().isoformat()
        emit([e for e in sorted(data['entries'].values(), key=lambda e: e['id'])
              if e['status'] == 'trial' and (args.all or e.get('review_at', '') <= today)])


def close(args):
    check_id(args.id)
    if args.status in ('promoted', 'merged'):
        require(args.approved and args.target, 'promotion/merge requires --approved and --target')
        require(Path(args.target).is_file(), 'destination skill file does not exist')
    with registry() as data:
        e = get_entry(data, args.id)
        require(e['status'] == 'trial', 'not in trial')
        e['status'] = args.status
        if args.target:
            e['promoted_to'] = args.target
        commit(data, 'close', args.id, {'status': args.status, 'target': args.target})
        emit({'id': args.id, 'status': args.status})


def listing(_args):
    with registry() as data:
        emit(data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    p = sub.add_parser('observe')
    for field in ('id', 'project', 'goal', 'trigger', 'evidence'):
        p.add_argument('--' + field, required=True)
    p.add_argument('--outcome', choices=RESULTS, default='unknown')
    p.add_argument('--scope', choices=('project', 'stack', 'global'), default='project')
    p.set_defaults(func=observe)
    p = sub.add_parser('candidate')
    p.add_argument('--id', required=True)
    p.add_argument('--from', dest='from_file', required=True)
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
    p = sub.add_parser('close')
    p.add_argument('--id', required=True)
    p.add_argument('--status', required=True, choices=STATUSES)
    p.add_argument('--target', default='')
    p.add_argument('--approved', action='store_true')
    p.set_defaults(func=close)
    p = sub.add_parser('list')
    p.set_defaults(func=listing)
    args = parser.parse_args()
    try:
        args.func(args)
    except (ValueError, OSError, UnicodeError, json.JSONDecodeError) as exc:
        parser.exit(1, f'error: {exc}\n')


if __name__ == '__main__':
    main()

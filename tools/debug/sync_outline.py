import json, urllib.request, os, sys

KEY = 'nxb-K8n3gHjvz3M4zV8cC4X4FhRq2r2i6N1jL5kM1s'
BASE = 'https://outline.nas.thinksdesign.com/api'

docs = {
    '4f19f637-60dd-4ed1-ae88-b991dfa10a6a': 'docs/spec.md',
    '29462fd5-5607-43d0-a10e-0a8922330e0e': 'docs/project-structure.md',
    '6ba5603f-716c-443c-87e9-34b960f1588c': 'docs/plan.md',
}

root = r'C:\Users\Nick Lo\Development\letter-rogue'

for doc_id, rel_path in docs.items():
    path = os.path.join(root, rel_path)
    with open(path, 'r', encoding='utf-8') as f:
        text = f.read()
    
    payload = json.dumps({'id': doc_id, 'text': text, 'publish': True}).encode('utf-8')
    req = urllib.request.Request(
        f'{BASE}/documents.update',
        data=payload,
        headers={
            'Authorization': f'Bearer {KEY}',
            'Content-Type': 'application/json',
        }
    )
    try:
        with urllib.request.urlopen(req) as resp:
            result = json.loads(resp.read().decode('utf-8'))
            status = 'OK' if result.get('ok') else 'FAIL'
            print(f'{rel_path}: {status}')
    except Exception as e:
        print(f'{rel_path}: ERROR {e}')
        sys.exit(1)

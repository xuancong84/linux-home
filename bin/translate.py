#!/opt/anaconda3/bin/python3
# -*- coding: utf-8 -*-

import argparse, time, random
import os, sys, gzip, re, difflib, unicodedata
import requests
from urllib.parse import quote
from tqdm import tqdm

# googletrans stopped working: its translate_a/single endpoint now returns a CAPTCHA page and
# googletrans silently returns the source text. Call Google endpoints that still work directly.
UA = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36'
PA_KEY = 'AIzaSyDLEeFI5OtFBwYBIoK_jj5m32rZK5CkCXA'	# public key used by the Google Translate web client
PA_MAX_URL_TEXT = 12000	# max URL-encoded text length for translate-pa
session = requests.Session()
session.headers['User-Agent'] = UA


def Open(fn, mode='r', **kwargs):
	if fn == '-':
		return open(sys.stdin.fileno(), mode) if mode.startswith('r') else sys.stdout
	fn = os.path.expanduser(fn)
	return gzip.open(fn, mode, **kwargs) if fn.lower().endswith('.gz') else open(fn, mode, **kwargs)


def norm_lang(lang):
	# zh-cn => zh-CN, zh_tw => zh-TW
	p = lang.replace('_', '-').split('-')
	return '-'.join([p[0].lower()] + [x.upper() for x in p[1:]])


def gtrans_clients5(txt, src, dst):
	r = session.post('https://clients5.google.com/translate_a/t', timeout = 60,
		params = {'client': 'dict-chrome-ex', 'sl': src, 'tl': dst}, data = {'q': txt})
	r.raise_for_status()
	res = r.json()[0]
	# with sl=auto the result is [text, detected_lang], otherwise just text
	return (res[0], res[1]) if isinstance(res, list) else (res, src)


def gtrans_pa(txt, src, dst):
	# this endpoint only accepts GET, so the request URL (max ~16KB) limits the text length
	params = {'params.client': 'gtx', 'query.source_language': src, 'query.target_language': dst,
		'query.display_language': 'en-US', 'data_types': 'TRANSLATION', 'key': PA_KEY}
	if len(quote(txt)) > PA_MAX_URL_TEXT:
		lines = txt.split('\n')
		if len(lines) < 2:
			raise ValueError('single line too long for translate-pa')
		mid = len(lines)//2
		r1, l1 = gtrans_pa('\n'.join(lines[:mid]), src, dst)
		r2, l2 = gtrans_pa('\n'.join(lines[mid:]), src, dst)
		return r1+'\n'+r2, l1
	r = session.get('https://translate-pa.googleapis.com/v1/translate', params = dict(params, **{'query.text': txt}), timeout = 60)
	r.raise_for_status()
	res = r.json()
	return res['translation'], res.get('sourceLanguage', src)


def gtrans(txt, src, dst):
	src, dst = norm_lang(src), norm_lang(dst)
	for n_try in range(100):
		for backend in [gtrans_clients5, gtrans_pa]:
			try:
				return backend(txt, src, dst)
			except Exception as e:
				print(f'{backend.__name__} failed: {e!r}', file = sys.stderr)
		time.sleep(random.randint(1, 5))
	sys.exit('Translation failed after many retries')


def gtrans_multi(txts, src, dst, maxlen = 20000):
	# translate a list of segments, each one separately language-identified when src is auto
	if not txts:
		return []
	src, dst = norm_lang(src), norm_lang(dst)
	out, batch, batch_len = [], [], 0
	for t in txts+[None]:
		if t is None or (batch and batch_len+len(t) > maxlen):
			for n_try in range(100):
				try:
					r = session.post('https://clients5.google.com/translate_a/t', timeout = 60,
						params = {'client': 'dict-chrome-ex', 'sl': src, 'tl': dst}, data = [('q', x) for x in batch])
					r.raise_for_status()
					res = r.json()
					if len(res) != len(batch):
						raise ValueError(f'got {len(res)} results for {len(batch)} segments')
					out += [x[0] if isinstance(x, list) else x for x in res]
					break
				except Exception as e:
					print(f'gtrans_multi failed: {e!r}', file = sys.stderr)
					if n_try >= 2:	# fall back to one request per segment
						out += [gtrans(x, src, dst)[0] for x in batch]
						break
					time.sleep(random.randint(1, 5))
			batch, batch_len = [], 0
		if t is not None:
			batch += [t]
			batch_len += len(t)
	return out


PUNCT_MAP = str.maketrans({'。': '.', '，': ',', '、': ',', '…': '...', '！': '!', '？': '?', '：': ':', '；': ';',
	'“': '"', '”': '"', '‘': "'", '’': "'", '「': '"', '」': '"', '《': '"', '》': '"'})

def norm_text(s):
	# strip subtitle markup and punctuation, keep only lowercased letters/digits
	s = re.sub(r'<[^>]*>|\{\\[^}]*\}', '', s)
	s = unicodedata.normalize('NFKC', s).translate(PUNCT_MAP).casefold()
	return ''.join(c for c in s if c.isalnum())


SRT_STRUCT = re.compile(r'^\d+$|^\d\d:\d\d:\d\d[,.]\d{3}\s*-->\s*\d\d:\d\d:\d\d[,.]\d{3}')

def is_untranslated(src_line, res_line):
	if SRT_STRUCT.match(src_line):	# never re-send SRT index/timestamp lines
		return False
	a, b = norm_text(src_line), norm_text(res_line)
	if sum(c.isalpha() for c in a) < 3:
		return False
	return a == b or difflib.SequenceMatcher(None, a, b, autojunk = False).ratio() >= 0.9


def fix_untranslated(src_lines, res_lines, dst, maxlen):
	# with src=auto, Google identifies one language for the whole chunk and leaves lines in other languages
	# untranslated, re-send those lines as separate segments so that each one is language-identified on its own
	idx = [i for i, (s, r) in enumerate(zip(src_lines, res_lines)) if s and is_untranslated(s, r)]
	res_lines = list(res_lines)
	for i, r in zip(idx, gtrans_multi([src_lines[i] for i in idx], 'auto', dst, maxlen)):
		if not is_untranslated(src_lines[i], r):
			print(f'Re-translated: {src_lines[i]!r} => {r!r}', file = sys.stderr)
			res_lines[i] = r
	return res_lines


def translate(txt, src, dst):
	res = gtrans(txt, src, dst)[0]
	src_lines, res_lines = txt.split('\n'), res.split('\n')
	if len(src_lines) != len(res_lines):
		# translate-pa sometimes inserts extra blank lines, realign by non-blank lines if possible
		res_nz = iter([L for L in res_lines if L.strip()])
		if sum(1 for L in src_lines if L) == sum(1 for L in res_lines if L.strip()):
			res_lines = [next(res_nz) if L else '' for L in src_lines]
	if len(src_lines) != len(res_lines):
		# Google merged/split some lines, bisect so that line alignment (important for SRT) is kept
		nz = [i for i, L in enumerate(src_lines) if L]
		if len(nz) < 2:
			return res
		mid = nz[len(nz)//2]
		return translate('\n'.join(src_lines[:mid]), src, dst)+'\n'+translate('\n'.join(src_lines[mid:]), src, dst)
	# keep lines without letters (e.g., SRT indices/timestamps) verbatim, Google sometimes turns "376" into "第376章"
	return '\n'.join(s if not any(c.isalpha() for c in s) else r for s, r in zip(src_lines, res_lines))


def split_long_line(L, maxlen):
	# split a line longer than maxlen at sentence ends, then at spaces, then anywhere
	out = []
	while len(L) > maxlen:
		cut = max(L.rfind(c, 0, maxlen) for c in '.!?;。！？；')
		if cut <= 0:
			cut = L.rfind(' ', 0, maxlen)
		cut = cut+1 if cut > 0 else maxlen
		out += [L[:cut].strip()]
		L = L[cut:].strip()
	return out + [L]


def make_chunks(lines, maxlen):
	# greedily pack lines into chunks of at most maxlen characters, cutting preferably at the last blank line
	# unless that would move more than 10% of maxlen to the next chunk, otherwise cutting at end-of-line;
	# also returns, for each piece, whether it continues the previous line (split from a long line)
	pieces = [(piece, i > 0) for L in lines for i, piece in enumerate(split_long_line(L, maxlen) if len(L) > maxlen else [L])]
	chunks, conts, cur, cur_len = [], [], [], 0
	for piece, cont in pieces:
		if cur and cur_len+1+len(piece) > maxlen:
			blank = max((i for i, (L, _) in enumerate(cur) if not L), default = -1)
			tail_len = sum(len(L)+1 for L, _ in cur[blank+1:])
			cut = blank+1 if blank > 0 and tail_len <= maxlen//10 else len(cur)
			chunks += [[L for L, _ in cur[:cut]]]
			conts += [[c for _, c in cur[:cut]]]
			cur = cur[cut:]
			cur_len = sum(len(L) for L, _ in cur)+max(len(cur)-1, 0)
		cur_len += (1 if cur else 0)+len(piece)
		cur += [(piece, cont)]
	if cur:
		chunks += [[L for L, _ in cur]]
		conts += [[c for _, c in cur]]
	return chunks, conts


def main():
	parser = argparse.ArgumentParser(
		description = 'Python Google Translator as a command-line tool')
	parser.add_argument('text', help = 'The text you want to translate.', nargs = '?')
	parser.add_argument('-d', '--dest', default = 'en', help = 'The destination language you want to translate. (Default: en)')
	parser.add_argument('-s', '--src', default = 'auto', help = 'The source language you want to translate. (Default: auto)')
	parser.add_argument('-c', '--detect', action = 'store_true', default = False, help = 'Detect source language, print language type')
	parser.add_argument('-i', '--file', default = '', help = 'Input file, this has the highest priority')
	parser.add_argument('-o', '--output', default = '-', help = 'Output file, Default: - for STDOUT')
	parser.add_argument('-n', '--split-threshold', type = int, default = 20000, help = 'Character limit for splitting into multiple batches')
	args = parser.parse_args()

	fp_out = Open(args.output, 'w')

	if args.detect:
		print(gtrans(args.text, 'auto', args.dest)[1], file=fp_out)
		return

	if args.file:
		text = Open(args.file, 'rt').read()
	elif args.text is None:
		text = open(sys.stdin.fileno()).read()
	else:
		text = args.text

	# languages written without spaces between words/sentences
	joiner = '' if norm_lang(args.dest).split('-')[0] in ('zh', 'ja', 'ko', 'th', 'lo', 'km', 'my') else ' '
	lines = [L.strip() for L in text.splitlines()]
	chunks, conts = make_chunks(lines, args.split_threshold)
	n_out = 0	# number of output lines printed, a continuation piece is appended to the previous line
	for chunk, cont in zip(tqdm(chunks), conts):
		# translate only the inner part, leading/trailing blank lines would be dropped by Google
		beg = next((i for i, L in enumerate(chunk) if L), len(chunk))
		end = len(chunk)-next((i for i, L in enumerate(reversed(chunk)) if L), 0)
		res = translate('\n'.join(chunk[beg:end]), args.src, args.dest).split('\n') if beg < end else []
		if res and args.src == 'auto':
			res = fix_untranslated(chunk[beg:end], res, args.dest, args.split_threshold)
		out = chunk[:beg] + res + chunk[end:]
		for i, L in enumerate(out):
			if cont[i]:
				print(joiner+L, end='', file=fp_out)
			else:
				print(('\n' if n_out else '')+L, end='', file=fp_out)
				n_out += 1
		fp_out.flush()
	if n_out:
		print(file=fp_out)

if __name__ == '__main__':
	main()

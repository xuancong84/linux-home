import os, sys, argparse, re
flask_stupid = globals
from flask import *
globals = flask_stupid

app = Flask(__name__)


@app.after_request
def after_request(response):
	response.headers.add('Accept-Ranges', 'bytes')
	return response


def get_chunk(byte1 = None, byte2 = None, vid_name = None):
	full_path = root_path + vid_name
	file_size = os.stat(full_path).st_size
	start = 0

	if byte1 < file_size:
		start = byte1
	if byte2:
		length = byte2 + 1 - byte1
	else:
		length = file_size - start

	with open(full_path, 'rb') as f:
		f.seek(start)
		chunk = f.read(length)
	return chunk, start, length, file_size


@app.route('/<vid_name>')
def get_file(vid_name):
	range_header = request.headers.get('Range', None)
	byte1, byte2 = 0, None
	if range_header:
		match = re.search(r'(\d+)-(\d*)', range_header)
		groups = match.groups()

		if groups[0]:
			byte1 = int(groups[0])
		if groups[1]:
			byte2 = int(groups[1])

	chunk, start, length, file_size = get_chunk(byte1, byte2, vid_name)
	resp = Response(chunk, 206, mimetype = 'video/mp4', content_type = 'video/mp4', direct_passthrough = True)
	resp.headers.add('Content-Range', 'bytes {0}-{1}/{2}'.format(start, start + length - 1, file_size))
	return resp


if __name__ == '__main__':
	parser = argparse.ArgumentParser(usage = '$0 <root-path-to-serve> 1>output 2>progress', description = 'This program hosts a folder with range request (RFC 7233) using HTTP',
	                                 formatter_class = argparse.ArgumentDefaultsHelpFormatter)
	parser.add_argument('root_path', help = 'the root path to serve')
	parser.add_argument('--ip', '-i', help = 'the host interface (IP address) to bind', default = '0.0.0.0')
	parser.add_argument('--port', '-p', help = 'the port number to listen', default = 8001, type = int)
	# nargs='?': optional positional argument; action='append': multiple instances of the arg; type=; default=
	opt = parser.parse_args()
	globals().update(vars(opt))

	root_path = os.path.expanduser(root_path).rstrip('/') + '/'
	app.run(threaded = True, host = ip, port = port)
